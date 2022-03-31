package cache

import (
	"github.com/patrickmn/go-cache"
	"time"
)

// New Create a cache with a default expiration time of 5 minutes, and which
// purges expired items every 2 minutes
func New() *cache.Cache {
	c := cache.New(5*time.Minute, 2*time.Minute)
	return c
}
