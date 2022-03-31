package cache_test

import (
	"github.com/cloudradar-monitoring/rport-pairing/internal/cache"
	"github.com/stretchr/testify/assert"
	"testing"
	"time"
)

func TestCache(t *testing.T) {
	c := cache.New()
	c.Set("test", 9999, 2*time.Second)
	v, _ := c.Get("test")
	assert.Equal(t, 9999, v)
	c.Set("void", "ok", 1*time.Second)
	time.Sleep(2 * time.Second)
	v, ok := c.Get("void")
	assert.Nil(t, v)
	assert.False(t, ok)
}
