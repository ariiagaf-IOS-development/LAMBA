package repository

import "errors"

var (
	ErrConflict = errors.New("conflict")
	ErrNotFound = errors.New("not found")
)
