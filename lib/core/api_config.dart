class ApiConfig {
  // Insira o link do seu servidor onde está a pasta api/
  static const String baseUrl = "https://nanostream.amanhecermavoco.edu.mz/api";
  
  static const String loginEndpoint = "$baseUrl/login.php";
  static const String registerEndpoint = "$baseUrl/register.php";
  static const String contentEndpoint = "$baseUrl/get_content.php";
}