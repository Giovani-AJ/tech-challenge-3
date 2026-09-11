variable "queue_name" {
  type    = string
  default = "togglemaster-evaluation-events"
}

variable "visibility_timeout_seconds" {
  type    = number
  default = 30
}
