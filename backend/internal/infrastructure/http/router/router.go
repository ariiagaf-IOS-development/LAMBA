package router

import (
	"database/sql"
	"log/slog"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
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

		authService := service.NewAuthService(userRepo, dep.Config.BcryptCost)
		vehicleService := service.NewVehicleService(vehicleRepo)
		eventService := service.NewVehicleEventService(eventRepo)
		timelineService := service.NewTimelineService(eventService)

		authHandler := handler.NewAuthHandler(authService, log)
		vehicleHandler := handler.NewVehicleHandler(vehicleService, log)
		eventHandler := handler.NewVehicleEventHandler(eventService, timelineService, log)

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
			protected.GET("/vehicles/:id/timeline", eventHandler.GetTimeline)
			protected.PATCH("/vehicles/:id/events/:eventId", eventHandler.UpdateEvent)
			protected.DELETE("/vehicles/:id/events/:eventId", eventHandler.DeleteEvent)
		}
	}

	return r
}
