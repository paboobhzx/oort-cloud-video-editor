#Cognito User Pool
resource "aws_cognito_user_pool" "main" { 
    name = "${var.project_name}-${var.environment}-user-pool"
    #Allow users to sign in with email
    username_attributes = ["email"]
    auto_verified_attributes = ["email"]
    #Password Policy
    password_policy { 
        minimum_length = 8
        require_lowercase = true
        require_uppercase = true
        require_numbers = true 
        require_symbols = false
    }
    #Account Recovery
    account_recovery_setting { 
        recovery_mechanism { 
            name = "verified_email"
            priority = 1
        }
    }
    #Email configuration
    email_configuration { 
        email_sending_account = "COGNITO_DEFAULT"
    }
    #User Attributes
    schema { 
        name = "email"
        attribute_data_type = "String"
        required = true
        mutable = false 
    }
    tags = merge( 
        var.tags,
        { 
            Name = "${var.project_name}-${var.environment}-user-pool"
        }
    )
}
#Cognito User Pool client
resource "aws_cognito_user_pool_client" "main" { 
    name = "${var.project_name}-${var.environment}-client"
    user_pool_id = aws_cognito_user_pool.main.id 
    #OAuth Flows
    allowed_oauth_flows_user_pool_client = true 
    allowed_oauth_flows = [ "code", "implicit"]
    allowed_oauth_scopes = ["email", "openid", "profile"]
    #Callback URLS - update with your actual frontend urls
    callback_urls = [ 
        "http://localhost:4200",
        "http://localhost:4200/callback"
    ]
    logout_urls = [ 
        "http://localhost:4200",
        "http://localhost:4200/logout"
    ]
    #Token validity
    access_token_validity = 60 #Minutes
    id_token_validity = 60 #Minutes
    refresh_token_validity = 30 #Days
    token_validity_units { 
        access_token = "minutes"
        id_token = "minutes"
        refresh_token = "days"
    }
    #Auth flows
    explicit_auth_flows = [ 
        "ALLOW_USER_SRP_AUTH",
        "ALLOW_REFRESH_TOKEN_AUTH",
        "ALLOW_USER_PASSWORD_AUTH"
    ]
    #Prevent user existence errors
    prevent_user_existence_errors = "ENABLED"
    #Read and write attributes
    read_attributes = ["email", "email_verified"]
    write_attributes = ["email"]
}
#Cognito User Po9ol Domain (for hosted UI - optional)
resource "aws_cognito_user_pool_domain" "main" { 
    domain = "${var.project_name}-${var.environment}-${random_string.cognito_domain.result}"
    user_pool_id = aws_cognito_user_pool.main.id 
}
#Random string for uniqque cognito domain
resource "random_string" "cognito_domain" { 
    length = 8
    special = false
    upper = false 
}