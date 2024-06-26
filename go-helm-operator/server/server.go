package server

import (
	"context"
	"go-helm-operator/go-helm-operator/auth"
	"go-helm-operator/go-helm-operator/configuration"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"

	"github.com/gorilla/websocket"
	"github.com/rs/cors"
)

var shutdown os.Signal = syscall.SIGUSR1

var (
	// Buildtime is set to the current time during the build process by GOLDFLAGS
	Buildtime string
	// Version is set to the current git tag during the build process by GOLDFLAGS
	Version string
)

var (
	CPUProfile   string
	PrintVersion bool
	PProf        bool
)

// StartOpts is passed to StartServer() and is used to set the running configuration
type StartOpts struct {
}

type ServerOpts struct {
	Config *configuration.ServerConfig
}

type Server struct {
	mu sync.Mutex

	Config *configuration.ServerConfig

	Mux *http.ServeMux

	Clients map[*websocket.Conn]string
}

func NewServer(config *configuration.ServerConfig) *Server {
	// TODO: Implement database fetch for existing rooms
	// rooms := db.getRooms()

	auth.NewCookieStore()

	return &Server{
		Config:  config,
		Clients: make(map[*websocket.Conn]string),
	}
}

func (s *Server) setupRoutes(mux *http.ServeMux) {
	http.HandleFunc("/users/login", auth.Login)
	http.HandleFunc("/users", s.getUsers)
	// http.HandleFunc("/users/register", auth.Register)

	http.HandleFunc("/", s.home)
}

func (s *Server) StartServer(opts *StartOpts) error {
	crt, _ := os.ReadFile(s.Config.ServerTLSCert)
	if string(crt) != "" {
		// TODO: Enable TLS
		s.Config.Log.Info().Msg("Received TLS Certs")
	}
	s.Mux = http.NewServeMux()

	s.setupRoutes(s.Mux)

	c := cors.Default()

	// Wrap the mux with the CORS middleware
	handler := c.Handler(http.DefaultServeMux)

	server := &http.Server{Addr: s.Config.ServerListenAddress, Handler: handler}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)

	go func() {
		log.Printf("Starting server on %s\n", s.Config.ServerListenAddress)
		if err := server.ListenAndServe(); err != nil {
			log.Printf("error starting server: %s", err)
			stop <- shutdown
		}
	}()

	signal := <-stop
	log.Printf("Shutting down server ... ")

	server.Shutdown(context.TODO())
	if signal == shutdown {
		return nil
	}
	return nil
}
