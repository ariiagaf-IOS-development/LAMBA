package handler

import "github.com/gin-gonic/gin"

type ErrorResponse struct {
	Error string `json:"error" example:"invalid request"`
}

func errorJSON(c *gin.Context, status int, message string) {
	c.JSON(status, ErrorResponse{Error: message})
}
