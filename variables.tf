variable "name" {
  type = string
  description = "a single word to be added to the VM name to describe the VM (ex. 'WEB01')"
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

variable "vmsize" {
  type        = string
  description = "the vmsize sku"
  default = "Standard_DS1_v2"
}

variable "morph_url" {
  type = string
  description = "url of the morpheus appliance"
}

variable "morph_api_key" {
  type = string
  description = "api key for the morpheus appliance"
  sensitive   = true
}

/*
variable "kv_name" {
  type        = string
  description = "the name of the existing azure key vault in which to store azureuser password"
}
*/