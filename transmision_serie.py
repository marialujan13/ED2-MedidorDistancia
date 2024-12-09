import serial

def recibir_datos_puerto_serial(puerto, baudrate):
    try:
        # Configurar el puerto serie
        ser = serial.Serial(puerto, baudrate, timeout=1)
        print(f"Conectado al puerto {puerto} con baudrate {baudrate}")
        print()
        
        while True:
            if ser.in_waiting > 0:
                print("-----------------------Transmisión recibida-----------------------")
                print()
                # Leer los datos brutos como bytes
                data_raw = ser.readline()
                print(f"Datos brutos recibidos: {data_raw}")
                print()
                # Mostrar los datos brutos en formato hexadecimal
                hex_data = data_raw.hex()
                # Convertir los datos hexadecimales a valores decimales
                valores_decimales = [int(hex_data[i:i+2], 16) for i in range(0, len(hex_data), 2)]
                
                # Imprimir los valores decimales sin comas ni espacios
                print("Distancia medida: ", end="")
                for valor in valores_decimales:
                    print(f"{valor}", end="")
                    # Imprimir la unidad de medida al final
                print(" cm")
                print()  # Imprimir una nueva línea después de los valores

    except serial.SerialException as e:
        print(f"Error de comunicación: {e}")
    except KeyboardInterrupt:
        print("Interrupción del usuario")
    finally:
        ser.close()
        print("Puerto serie cerrado")

if __name__ == "__main__":
    # Cambia estos valores según sea necesario
    PUERTO = 'COM3'  # Ejemplo para Windows. En Linux puede ser '/dev/ttyUSB0'
    BAUDRATE = 9600  # Asegúrate de que coincida con el baudrate del PIC

    recibir_datos_puerto_serial(PUERTO, BAUDRATE)


