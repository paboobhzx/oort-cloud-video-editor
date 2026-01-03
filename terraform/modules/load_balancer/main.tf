resource "aws_lb" "main" { 
    name = "${var.project_name}-${var.environment}-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [var.security_group_id]
    subnets = var.public_subnet_ids

    enable_deletion_protection = false 
    enable_http2 = true 
    enable_cross_zone_load_balancing = true
    tags = merge( 
        var.tags, { 
            Name = "${var.project_name}-${var.environment}-alb"
        }
    )
}

#Target group for EC2 instances
resource "aws_lb_target_group" "video_processors" { 
    name = "${var.project_name}-${var.environment}-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = var.vpc_id 
    #Health check configuration
    health_check { 
        enabled = true
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 5
        interval = 30
        path = "/health"
        protocol = "HTTP"
        matcher = "200"
    }
    #Deregistration delay
    deregistration_delay = 30

    tags = merge(
        var.tags, 
        { 
            Name = "${var.project_name}-${var.environment}-tg"
        }
    ) 
}
#HTTP Listener (Port 80)
resource "aws_lb_listener" "http" { 
    load_balancer_arn = aws_lb.main.arn 
    port = 80
    protocol = "HTTP"

    default_action { 
        type = "forward"
        target_group_arn = aws_lb_target_group.video_processors.arn 
    }

    tags = merge( 
        var.tags, 
        { 
            Name = "${var.project_name}-${var.environment}-http-listener"
        }
    )

    
}
#HTTPS Listener (Port 443) - If you have an ACM certificate, uncomment
#resource "aws_lb_listener" "https" { 
#    load_balancer_arn = aws_lb.main.arn 
#    port = 443 
#    protocol = "HTTPS"
#    ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#    certificate_arn = var.acm_certificate_arn 
#
#    default_action { 
#        type = "forward"
#        target_group_arn = aws_lb_target_group.video_processors.arn 
#    }
#    tags = merge ( 
#        var.tags, 
#        { 
#            Name = "${var.project_name}-${var.environment}-https-listener"
#        }
#    )
#} 
#Listener Rule - Forward to target group
resource "aws_lb_listener_rule" "forward_to_processors" { 
    listener_arn = aws_lb_listener.http.arn 
    priority = 100 

    action { 
        type = "forward"
        target_group_arn = aws_lb_target_group.video_processors.arn 
    }
    condition { 
        path_pattern { 
            values = ["/*"]
        }
    }
}

