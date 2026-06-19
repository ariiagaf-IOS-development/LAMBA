package router

import (
	"database/sql"
	"log/slog"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/provider"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/service"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/config"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/http/handler"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/http/middleware"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

type Dependencies struct {
	Config config.Config
	DB     *sql.DB
	Logger *slog.Logger
}

func New(deps ...Dependencies) *gin.Engine {
	var dep Dependencies
	if len(deps) > 0 {
		dep = deps[0]
	}

	log := dep.Logger
	if log == nil {
		log = slog.Default()
	}

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	healthHandler := handler.NewHealthHandler(dep.DB)
	r.GET("/health", healthHandler.CheckHealth)
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	if dep.DB != nil {
		userRepo := repository.NewUserRepository(dep.DB)
		vehicleRepo := repository.NewVehicleRepository(dep.DB)
		eventRepo := repository.NewVehicleEventRepository(dep.DB)
		partRepo := repository.NewPartRepository(dep.DB)
		predictionRepo := repository.NewPredictionRepository(dep.DB)

		var predictionProvider provider.PredictionProvider

		switch dep.Config.PredictionProvider {
		case config.PredictionProviderMock:
			predictionProvider = provider.NewMockPredictionProvider()
		default:
			predictionProvider = provider.NewRuleBasedPredictionProvider()
		}

		log.Info("prediction provider selected", slog.String("provider", string(dep.Config.PredictionProvider)))

		authService := service.NewAuthService(userRepo, dep.Config.BcryptCost)
		vehicleService := service.NewVehicleService(vehicleRepo)
		predictionService := service.NewPredictionService(
			vehicleRepo,
			eventRepo,
			partRepo,
			predictionRepo,
			predictionProvider,
		)
		eventService := service.NewVehicleEventService(eventRepo, partRepo, predictionService)

		authHandler := handler.NewAuthHandler(authService, log)
		vehicleHandler := handler.NewVehicleHandler(vehicleService, log)
		eventHandler := handler.NewVehicleEventHandler(eventService, log)
		predictionHandler := handler.NewPredictionHandler(predictionService)

		api := r.Group("/api")
		{
			auth := api.Group("/auth")
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)

			protected := api.Group("")
			protected.Use(middleware.BasicAuth(authService))
			protected.GET("/me", authHandler.Me)
			protected.POST("/vehicles", vehicleHandler.CreateVehicle)
			protected.GET("/vehicles", vehicleHandler.ListVehicle)
			protected.GET("/vehicles/:id", vehicleHandler.GetVehicle)
			protected.PATCH("/vehicles/:id", vehicleHandler.UpdateVehicle)
			protected.DELETE("/vehicles/:id", vehicleHandler.DeleteVehicle)

			protected.POST("/vehicles/:id/events", eventHandler.CreateEvent)
			protected.GET("/vehicles/:id/events", eventHandler.ListEvents)
			protected.GET("/vehicles/:id/events/stats", eventHandler.GetEventStats)
			protected.GET("/vehicles/:id/timeline", eventHandler.GetTimeline)
			protected.PATCH("/vehicles/:id/events/:eventId", eventHandler.UpdateEvent)
			protected.DELETE("/vehicles/:id/events/:eventId", eventHandler.DeleteEvent)
			protected.GET("/vehicles/:id/predictions", predictionHandler.GetByVehicle)
		}
	}

	return r
}
