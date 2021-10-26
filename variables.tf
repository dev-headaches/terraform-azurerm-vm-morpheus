variable "name" {
  type = string
  description = "a single word to be added to the VM name to describe the VM (ex. 'WEB01')"
}
variable "kv_name" {
  type        = string
  description = "the name of the existing azure key vault in which to store azureuser password"
}
variable "prjnum" {
  type        = string
  description = "the existing project number used to deploy the hub"
}
variable "enviro" {
  type        = string
  description = "the environment name used for the hub deployment (default is 'dev')"
  default = "dev"
}
variable "orgname" {
  type        = string
  description = "the organization name used for the hub deployment"
}