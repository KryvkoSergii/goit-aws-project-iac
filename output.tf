###############################################
#  Outputs                                    #
###############################################
output "alb_dns_name" {
  value = aws_lb.api.dns_name
  description = "Public URL for the Application Load Balancer"
}

output "s3_static_website_url" {
  value = aws_s3_bucket_website_configuration.static_website.website_endpoint
}