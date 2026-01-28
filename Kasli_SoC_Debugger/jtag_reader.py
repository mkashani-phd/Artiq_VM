import serial

ser= serial.Serial('/dev/ttyUSB2', 115200)

while True:
    print(ser.readline())