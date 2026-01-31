// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Explicitly import and register dark_mode_controller to ensure it's available on page load
import DarkModeController from "controllers/dark_mode_controller"
application.register("dark-mode", DarkModeController)
