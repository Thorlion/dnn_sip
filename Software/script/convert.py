# Thư viện
import json
import numpy as np
from PIL import Image


def preprocess_image(image_path, target_size):
        im = Image.open(image_path)
        im = im.resize(target_size)  # Resize ảnh về kích thước cần thiết
        im = np.expand_dims(im, axis=0)  # Thêm chiều batch
        im = np.array(im) / 255.0  # Chuẩn hóa ảnh về [0, 1]

        return im

def convert_to_q8_8_hex(image_array, scale_factor=256):
    """
    Convert an image array to fixed-point Q8.8 hexadecimal representation.

    Parameters:
    - image_array: NumPy array of the image (assumes [0, 1] normalization).
    - scale_factor: Scaling factor for Q8.8 (default: 256 for 2^8).

    Returns:
    - hex_array: Array of hexadecimal strings in Q8.8 format.
    """
    # Scale the array to Q8.8 fixed-point range
    scaled_array = np.round(image_array * scale_factor).astype(int)
    # Clip values to fit into Q8.8 range [0, 255] (since only positive [0, 1] values are given)
    scaled_array = np.clip(scaled_array, 0, 255)
    # Convert each value to hexadecimal (without "0x" prefix)
    hex_array = np.vectorize(lambda x: f"{x:04X}")(scaled_array)

    return hex_array


process_type = 2  # 0: đọc weights conv, 1: đọc weights dense, 2: convert ảnh sang hex

# Đọc file CONV ###########
if process_type==0:
    # Đọc input weights và biases của convolution 0 - tiny network ##############################################################################
    # Đọc weights ===================================================
    file_path = 'D:/UIT/DoAn/codeDSIP/venv/model_tiny_test/conv2d.json'
    with open(file_path, 'r') as file:
        data = json.load(file)
    # Trích phần weights
    weights_conv0 = np.array(data.get('weights', []))
    # print(weights_conv0.shape)
    # Đổi định dạng từ (3, 3, 3, 32) thành (32, 3, 3, 3)
    eights_conv0 = np.transpose(weights_conv0, (3, 2, 0, 1))
    # print(weights_conv0.shape)
    # print((weights_conv0[0]))
    # Lưu weights_conv0 vào file weights_conv0.txt (giá trị thập phân)
    # output_file_path_decimal = 'testfile/inform_tiny_network/raw/weights_conv1.txt'
    # with open(output_file_path_decimal, 'w') as output_file:
    #     for weight in weights_conv0.flatten():  # Làm phẳng mảng và ghi từng giá trị
    #         output_file.write(f"{weight:.8f}\n")  # Ghi giá trị với độ chính xác 8 chữ số thập phân
    # print(f"Đã lưu weights_conv0 dưới dạng thập phân vào file: {output_file_path_decimal}")

    # Chuyển đổi các giá trị sang fixed-point 16-bit Q8.8
    weights_q8_8 = (weights_conv0 * 256).round().astype(np.int16)  # Nhân với 2^8 và làm tròn
    # Chuyển đổi từng giá trị sang hexa
    weights_hex = weights_q8_8.flatten()  # Làm phẳng mảng
    weights_hex_strings = [f"{ val:04X}" for val in weights_hex]  # Chuyển sang hex, định dạng 4 ký tự
    # Lưu vào file txt
    output_file_path = './model_tiny_test/file_hex/weights_conv0_hex.txt'
    with open(output_file_path, 'w') as output_file:
        for hex_val in weights_hex_strings:
            output_file.write(f"{hex_val}\n")  # Ghi mỗi giá trị hex trên một dòng
    print(f"Đã lưu weights_conv0 dưới dạng fixed-point Q8.8 hex vào file: {output_file_path}")



    # Đọc biases ===========================================================
    biases_conv0 = np.array(data.get('biases', []))
    # Lưu biases dưới dạng thập phân
    # biases_output_file_decimal = 'testfile/inform_tiny_network/raw/biases_conv1.txt'
    # with open(biases_output_file_decimal, 'w') as output_file:
    #     for bias in biases_conv0:
    #         output_file.write(f"{bias:.8f}\n")
    # print(f"Đã lưu biases_conv0 dưới dạng thập phân vào file: {biases_output_file_decimal}")

    # Chuyển đổi biases sang fixed-point Q8.8
    biases_q8_8 = (biases_conv0 * 256).round().astype(np.int16)
    biases_hex_strings = [f"{val:04X}" for val in biases_q8_8]

    # Lưu biases dưới dạng hex
    biases_output_file_hex = './model_tiny_test/file_hex/biases_conv0_hex.txt'
    with open(biases_output_file_hex, 'w') as output_file:
        for hex_val in biases_hex_strings:
            output_file.write(f"{hex_val}\n")
    print(f"Đã lưu biases_conv0 dưới dạng fixed-point Q8.8 hex vào file: {biases_output_file_hex}")



# ĐỌC FILE DENSE ############
elif process_type == 1:
    # đọc weights ====================================================================
    file_path = 'D:/UIT/DoAn/codeDSIP/venv/model_tiny_test/dense.json'
    with open(file_path, 'r') as file:
        data = json.load(file)
    # weights_dense = np.array(data.get('weights', []))
    # print(weights_dense.shape)
    # weights_dense = np.transpose(weights_dense, (1,0))
    # print(weights_dense.shape)
    # output_file_path_decimal = 'testfile/checkdense.json'
    # with open(output_file_path_decimal, 'w') as output_file:
    #     for weight in weights_dense.flatten():  # Làm phẳng mảng và ghi từng giá trị
    #         output_file.write(f"{weight:.8f}\n")  # Ghi giá trị với độ chính xác 8 chữ số thập phân
    # print(f"Đã lưu weights_conv0 dưới dạng thập phân vào file: {output_file_path_decimal}")
    weights = np.array(data.get("weights", []))

    # Bước 3: Chia thành các nhóm, mỗi nhóm gồm 6 phần tử lớn
    weights_dense = [weights[i:i + 6].tolist() for i in range(0, len(weights), 6)]
    weights_dense = np.array(weights_dense)
    # print(weights_dense.shape)
    weights_dense = np.transpose(weights_dense, (2, 1, 0))
    # print(weights_dense.shape)
    # grouped_weights = weights_dense.tolist()
    # with open('checkdense_4.json', 'w') as f:
    #     json.dump(grouped_weights, f, indent=2)

    # Chuyển đổi các giá trị sang fixed-point 16-bit Q8.8
    weights_q8_8 = (weights_dense * 256).round().astype(np.int16)  # Nhân với 2^8 và làm tròn
    # Chuyển đổi từng giá trị sang hexa
    weights_hex = weights_q8_8.flatten()  # Làm phẳng mảng
    weights_hex_strings = [f"{val:04X}" for val in weights_hex]  # Chuyển sang hex, định dạng 4 ký tự
    # Lưu vào file txt
    output_file_path = './model_tiny_test/file_hex/weights_dense0_hex.txt'
    with open(output_file_path, 'w') as output_file:
        for hex_val in weights_hex_strings:
            output_file.write(f"{hex_val}\n")  # Ghi mỗi giá trị hex trên một dòng
    print(f"Đã lưu weights_dense0 dưới dạng fixed-point Q8.8 hex vào file: {output_file_path}")


    # Đọc biases ===========================================================
    biases_dense = np.array(data.get('biases', []))
    # Lưu biases dưới dạng thập phân
    # biases_output_file_decimal = 'testfile/inform_tiny_network/raw/biases_conv1.txt'
    # with open(biases_output_file_decimal, 'w') as output_file:
    #     for bias in biases_conv0:
    #         output_file.write(f"{bias:.8f}\n")
    # print(f"Đã lưu biases_conv0 dưới dạng thập phân vào file: {biases_output_file_decimal}")

    # Chuyển đổi biases sang fixed-point Q8.8
    biases_q8_8 = (biases_dense * 256).round().astype(np.int16)
    biases_hex_strings = [f"{val:04X}" for val in biases_q8_8]

    # Lưu biases dưới dạng hex
    biases_output_file_hex = './model_tiny_test/file_hex/biases_dense0_hex.txt'
    with open(biases_output_file_hex, 'w') as output_file:
        for hex_val in biases_hex_strings:
            output_file.write(f"{hex_val}\n")
    print(f"Đã lưu biases_dense0 dưới dạng fixed-point Q8.8 hex vào file: {biases_output_file_hex}")





# CONVERT ảnh sang hexa
else:
    # Path to the image
    image_path = "D:/UIT/DoAn/codeDSIP/venv/model_test_final/image/truck.png"

    # Preprocess the image
    image_processed = np.array(preprocess_image(image_path, target_size=(32, 32)))
    image_processed_test = np.transpose(image_processed, (0, 3, 1, 2))

    # Convert to Q8.8 fixed-point hexadecimal
    q8_8_hex_values = convert_to_q8_8_hex(image_processed_test)

    # Save the Q8.8 values to a text file (one value per line)
    output_file = './model_test_final/convert_image/truck.txt'
    with open(output_file, "w") as f:
        for value in q8_8_hex_values.flatten():  # Flatten the multi-dimensional array
            f.write(f"{value}\n")  # Write each value on a new line

    print(f"Hexadecimal Q8.8 values saved to {output_file}")

