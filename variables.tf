variable "name" {
  type = string
  description = "a single word to be added to the VM name to describe the VM (ex. 'WEB01')"
}
variable "rgname" {
  type        = string
}
variable "kvid" {
  type        = string
  description = "the ID of the key vault in which to store azureuser password"
}
variable "subnetID" {
  type        = string
}
/**
variable "vmPubIPid" {
  type        = string
}

variable "wrkldID" {
  type        = string
  description = "a name/tag/id for the workload being created"
}
**/