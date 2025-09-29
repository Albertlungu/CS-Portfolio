#include <LiquidCrystal.h>

#define TRIG_PIN 11
#define ECHO_PIN 10
#define BUTTON_PIN 8
#define SENSOR_PIN A0        // Analog rotation sensor
#define BACKLIGHT_PIN 9      // PWM pin for LCD backlight

// LCD: RS, E, D4, D5, D6, D7
LiquidCrystal lcd(2, 3, 4, 5, 6, 7);

long duration;
float measuredDistance;
float calibratedHeight = 0;
float personHeight = 0;

bool measuring = false;
bool buttonPressed = false;
unsigned long buttonPressTime = 0;

int sensorValue;
int brightness;

void setup() {
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(BACKLIGHT_PIN, OUTPUT);

  lcd.begin(16, 2);
  lcd.print("Height: ");
}

void loop() {
  // --- Button handling ---
  int buttonState = digitalRead(BUTTON_PIN);

  // Button pressed
  if (buttonState == LOW && !buttonPressed) {
    buttonPressed = true;
    buttonPressTime = millis();
  }

  // Button released
  if (buttonState == HIGH && buttonPressed) {
    buttonPressed = false;
    unsigned long pressDuration = millis() - buttonPressTime;

    if (pressDuration > 1000) {
      // Long press: calibrate sensor to floor
      calibratedHeight = measureDistance();
      lcd.setCursor(0, 1);
      lcd.print("Calibrated      ");
      delay(1000);
    } else {
      // Short press: toggle measuring
      measuring = !measuring;
    }
  }

  // --- Measurement ---
  if (measuring) {
    measuredDistance = measureDistance();
    personHeight = calibratedHeight - measuredDistance;

    if (personHeight < 0) personHeight = 0; // prevent negative

    lcd.setCursor(0, 1);
    lcd.print("                "); // clear previous
    lcd.setCursor(0, 1);
    lcd.print(personHeight);
    lcd.print(" cm");
  }

  // --- Backlight Control ---
  sensorValue = analogRead(SENSOR_PIN);               // 0-1023
  brightness = map(sensorValue, 0, 1023, 0, 255);    // map to PWM
  analogWrite(BACKLIGHT_PIN, brightness);

  delay(100);
}

// Function to measure ultrasonic distance in cm
float measureDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long dur = pulseIn(ECHO_PIN, HIGH);
  return dur * 0.0343 / 2; // cm
}
