package router

import (
	"database/sql"
	"log/slog"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/config"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/handler"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/middleware"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/repository"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/service"
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
	r.GET("/health", healthHandler.Health)
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	if dep.DB != nil {
		userRepo := repository.NewUserRepository(dep.DB)
		vehicleRepo := repository.NewVehicleRepository(dep.DB)
		authService := service.NewAuthService(userRepo, dep.Config.BcryptCost)
		authHandler := handler.NewAuthHandler(authService)
		vehicleHandler := handler.NewVehicleHandler(vehicleRepo, slog.Default())

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
		}
	}

	return r
}
