#include <stdlib.h>
#include <SoftwareSerial.h>
#include <TinyGPS.h>
#include "MPU6050_tockn.h"
#include <Wire.h>
#include "time.h"
#include <SPI.h>
#include <SD.h>

#define SDPin 4
// Arduino Uno = pin 10
#define FILENAME "data.txt"

TinyGPS gps;
SoftwareSerial GPSSerial(2, 3);
MPU6050 mpu6050(Wire);

File dataFile;
String fileName;

extern volatile unsigned long timer0_millis;
unsigned long timeVal;
unsigned long readTime, lastWriteTime;
int year;
byte month, day, hour, minute, second, hundredths;
bool state = false, newGPSData = false;
float flat, flon;


void setup() {
  Serial.begin(115200);
  while (Serial == false)
  {
    // Wait for Connection
  }

  Serial.println("Notice: Initializing SD card...");

  
  if (SD.begin(SDPin) == false)
  {
  Serial.println(F("Alert: Card Initializing failed, or not present"));
  while (true);
  }
  Serial.println(F("Notice: Card Initializing Complete."));
  state = true;
  
  GPSSerial.begin(115200);
  Wire.begin();
  mpu6050.begin();
  mpu6050.setGyroOffsets(-9.87, -10.0, -0.31);

  if(SD.exists(FILENAME)){
    SD.remove(FILENAME);
  }
}

void loop() {
  //State - PC로부터 시간을 받아오고 파일 여는 것에 성공했을 시 true로 세팅됨, 그 후 아래 코드 실행됨
  if (state)
  {
    UpdateData();
    SendDataToPC();
    if (millis() - lastWriteTime >= 1000)
    {
      Serial.println("FIle writing start");
      WriteDataToSD();
      lastWriteTime = millis();
    }

  }
  else
  {
    Serial.println("Alert: Waiting for re-starting measurement");
    delay(2000);
  }

}

void serialEvent() {
  if (Serial.available() > 0)
  {
    String inString = Serial.readStringUntil('\n');
    int index1 = inString.indexOf(':');
    int index2 = inString.indexOf(':', index1 + 1);
    int index3 = inString.length();

    String receivedHour, receivedMin, receivedSec;

    receivedHour = inString.substring(0, index1);
    receivedMin = inString.substring(index1 + 1, index2);
    receivedSec = inString.substring(index2 + 1, index3);


    gps.crack_datetime(&year, &month, &day, &hour, &minute, &second, &hundredths);

    /*
      hour = receivedHour.toInt();
      minute = receivedMin.toInt();
      sec = receivedSec.toInt();

      timer0_millis = (((long)hour * 3600 + minute * 60 + sec) * 1000);
    */

    timeVal = millis();

    fileName = receivedHour + ":" + receivedMin + ":" + receivedSec + "측정 데이터.txt";


    // PC에서 전송받은 시간으로 파일 생성 후 초기 데이터 기록
    dataFile = SD.open(fileName, FILE_WRITE);

    if (dataFile)
    {
      dataFile.println("X축가속도값 Y축가속도값 Z축가속도값 X축Gyro값 Y축 Gyro값 Z축가속도값");
      dataFile.print(String(mpu6050.getAccX(), 6));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getAccY(), 6));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getAccZ(), 6));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getGyroX(), 6));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getGyroY(), 6));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getGyroZ(), 6));
      dataFile.print(",");
      dataFile.print(String(flat, 6));
      dataFile.print(",");
      dataFile.println(String(flon, 6));
      dataFile.close();
      lastWriteTime = millis();
      state = true; // 파일 여는 것에 성공했을 시 state true로 세팅
    }
    else
    {
      Serial.print(F("Alert: Error on File Opening"));
      Serial.println(fileName);
    }

  }
}

void UpdateData()
{

  mpu6050.update();


  //GPS
  while (GPSSerial.available())
  {
    char GPStmp = GPSSerial.read();
    // Serial.write(GPStmp); // uncomment this line if you want to see the GPS data flowing
    if (gps.encode(GPStmp)) // Did a new valid sentence come in?
      newGPSData = true;
  }

  //센서로부터 완전한 값을 읽어오는 것에 성공했다면 해당 값 저장
  if (newGPSData)
  {
    unsigned long age;
    gps.f_get_position(&flat, &flon);
    newGPSData = false;
  }
}

void SendDataToPC()
{
  if (millis() - timeVal >= 1000)
  {
    readTime = millis() / 1000;

    if (millis() >= 86400000)
    {
      timer0_millis = 0;
    }

    timeVal = millis();

    second += readTime % 60;
    minute += (readTime / 60) % 60;
    hour += (readTime / (3600)) % 24;
    Serial.print(hour);
    Serial.print(":");
    Serial.print(minute);
    Serial.print(":");
    Serial.println(second);
  }

  //축 가속도 값
  Serial.print(mpu6050.getAccX(), 6);
  Serial.print("\t");
  Serial.print(mpu6050.getAccY(), 6);
  Serial.print("\t");
  Serial.print(mpu6050.getAccZ(), 6);
  Serial.print("\t");

  //Gyro 값
  Serial.print(mpu6050.getGyroX(), 6);
  Serial.print("\t");
  Serial.print(mpu6050.getGyroY(), 6);
  Serial.print("\t");
  Serial.print(mpu6050.getGyroZ(), 6);
  Serial.print("\t");

  //축 기울기 값
  //Serial.print("angleX : ");
  Serial.print(mpu6050.getAngleX(), 6);
  Serial.print("\t");
  //Serial.print("\tangleY : ");
  Serial.print(mpu6050.getAngleY(), 6);
  Serial.print("\t");
  //Serial.print("\tangleZ : ");
  Serial.println(mpu6050.getAngleZ(), 6);

  // GPS 값
  Serial.print(flat == TinyGPS::GPS_INVALID_F_ANGLE ? 0.0 : flat, 6);
  Serial.print(" ");
  Serial.println(flon == TinyGPS::GPS_INVALID_F_ANGLE ? 0.0 : flon, 6);
  delay(500);
}

void WriteDataToSD()
{
  dataFile = SD.open(FILENAME, FILE_WRITE);
  if (dataFile)
  {
    int fileSize = dataFile.available();

    if (dataFile.seek(fileSize)) // 파일의 맨 마지막 캐릭터로 포인터 이동
    {
      dataFile.print(String((millis()/1000.00), 2));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getAccX(), 6));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getAccY(), 6));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getAccZ(), 6));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getGyroX(), 6));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getGyroY(), 6));
      dataFile.print(",");
      dataFile.print(String(mpu6050.getGyroZ(), 6));
      dataFile.print(",");
      dataFile.print(String(flat, 6));
      dataFile.print(",");
      dataFile.println(String(flon, 6));
      dataFile.close();
      Serial.println("File Write Success");
    }



    lastWriteTime = millis();
    state = true; // 파일 여는 것에 성공했을 시 state true로 세팅
  }
  else
  {
    Serial.print(F("Alert: Error on File Opening"));
    Serial.println(FILENAME);
    state = false;
  }
}
