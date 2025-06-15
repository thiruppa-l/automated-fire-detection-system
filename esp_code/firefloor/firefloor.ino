#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

const char* ssid = "lap1";
const char* password = "11111111";

ESP8266WebServer server(80);
const int fireSensor1 = D7;  // First floor sensor
const int fireSensor2 = D6;  // Second floor sensor

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);

  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected! IP Address: " + WiFi.localIP().toString());

  pinMode(fireSensor1, INPUT_PULLUP);
  pinMode(fireSensor2, INPUT_PULLUP);

  // API endpoint for both fire sensors
  server.on("/fire", []() {
    int status1 = digitalRead(fireSensor1);
    int status2 = digitalRead(fireSensor2);

    // Build JSON response
    String response = "{";
    response += "\"floor1\": \"" + String((status1 == LOW) ? "1" : "0") + "\", ";
    response += "\"floor2\": \"" + String((status2 == LOW) ? "1" : "0") + "\"";
    response += "}";

    // Send JSON response
    server.send(200, "application/json", response);
    
    // Print sensor data to Serial Monitor
    Serial.print("Sensor Data -> Floor1: ");
    Serial.print((status1 == LOW) ? "FIRE" : "NO FIRE");
    Serial.print(" | Floor2: ");
    Serial.println((status2 == LOW) ? "FIRE" : "NO FIRE");

    Serial.println("JSON Response sent: " + response);
  });

  server.begin();
}

void loop() {
  server.handleClient();
}
