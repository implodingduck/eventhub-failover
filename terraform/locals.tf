locals {
  cluster_name = "labby${random_string.unique.result}"
  func_name = "${local.cluster_name}func"
  loc_for_naming = "${lower(substr(var.location, 0, 1))}${lower(split(" ", var.location)[1])}"
  loc_for_naming2 = "${lower(substr(var.location2, 0, 1))}${lower(split(" ", var.location2)[1])}"
  gh_repo = replace(var.gh_repo, "implodingduck/", "")
  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
  }
}