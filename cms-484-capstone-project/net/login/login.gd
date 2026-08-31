extends Control

func _ready():
	var credentials = HCredentials.new()
	credentials.product_name = EOSCredentials.PRODUCT_NAME
	credentials.product_version = EOSCredentials.PRODUCT_VERSION
	credentials.product_id = EOSCredentials.PRODUCT_ID
	credentials.sandbox_id = EOSCredentials.SANDBOX_ID
	credentials.deployment_id = EOSCredentials.DEPLOYMENT_ID
	credentials.client_id = EOSCredentials.CLIENT_ID
	credentials.client_secret = EOSCredentials.CLIENT_SECRET
	credentials.encryption_key = EOSCredentials.ENCRYPTION_KEY

	var setup_success := await HPlatform.setup_eos_async(credentials)
	if not setup_success:
		printerr("Failed to setup EOS")
		return
		
	var logged_in := await HAuth.login_anonymous_async("name_id") # this function needs a name passed to it, this is the test
	if logged_in:
		print("Logged in: ", HAuth.product_user_id)
	else:
		print("Failed to log in")
