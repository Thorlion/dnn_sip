

def pre_processing(input_string):
    # Xóa toàn bộ dấu phẩy
    cleaned_input = input_string.replace(",", "")

    # Tách các phần tử dựa vào khoảng trắng
    elements = cleaned_input.split()

    # Hàm chuyển giá trị immediate sang nhị phân
    def convert_to_binary(value, bit_length):
        if value.startswith("0x"):  # Hexadecimal
            return f"{int(value, 16):0{bit_length}b}"
        elif value.startswith("0b"):  # Binary
            return f"{int(value, 2):0{bit_length}b}"
        else:  # Decimal
            return f"{int(value):0{bit_length}b}"

    # Từ điển opcode và ánh xạ thanh ghi
    opcode_mapping = {
        "ADD": "000000", "SUB": "000001", "MUL": "000010",
        "AND": "000011", "OR": "000100", "INC": "000101",
        "DEC": "000110", "ASR": "000111", "ADDI": "001000",
        "SUBI": "001001", "MULI": "001010", "ANDI": "001011",
        "ORI": "001100", "MOVHI": "001111", "MOV": "001101",
        "MOVLO": "001110", "OFMS": "010000", "OFML": "010001",
        "BR": "010011", "CBR": "010100", "SDC": "010101",
        "VSYNC": "010110", "END": "010111", "HSYNC": "011000",
        "OM2DNN": "100000", "OM2P0": "100001",
        "OM2P1": "100010", "DNN2OM": "100011"
    }
    register_mapping = {f"R{i}": f"{i:05b}" for i in range(32)}  # Tạo ánh xạ thanh ghi R0 -> R31 thành mã nhị phân 5 bit

    # Xử lý các loại lệnh
    if elements[0] in {"ADD", "SUB", "MUL", "AND", "OR", "INC", "DEC"}:
        opcode = opcode_mapping[elements[0]]
        rd = register_mapping.get(elements[1], "00000")
        ra = register_mapping.get(elements[2], "00000")
        rb = register_mapping.get(elements[3], "00000") if len(elements) > 3 else "00000"
        return f"{opcode}{rd}{ra}{rb}{'0' * 11}"

    elif elements[0] in {"ASR", "ADDI", "SUBI", "MULI", "ANDI", "ORI"}:
        opcode = opcode_mapping[elements[0]]
        rd = register_mapping.get(elements[1], "00000")
        ra = register_mapping.get(elements[2], "00000")
        imm16 = convert_to_binary(elements[3], 16)
        return f"{opcode}{rd}{ra}{imm16}"

    elif elements[0] in {"MOV", "MOVLO", "MOVHI"}:
        opcode = opcode_mapping[elements[0]]
        if elements[0] == "MOV":
            # imm16 = convert_to_binary(elements[2], 32)[-16:]  # Lấy 16 bit cuối của immediate 32 bit
            rd = register_mapping.get(elements[1], "00000")
            ra = register_mapping.get(elements[2], "00000")
            return f"{opcode}{rd}{ra}{'0' * 16}"
        elif elements[0] == "MOVLO" or elements[0] == "MOVHI":
            rd = register_mapping.get(elements[1], "00000")
            imm16 = convert_to_binary(elements[2], 16)
            return f"{opcode}{rd}{'0' * 5}{imm16}"

    elif elements[0] in {"OFMS", "OFML"}:
        opcode = opcode_mapping[elements[0]]
        rd = register_mapping.get(elements[1], "00000")
        ra = register_mapping.get(elements[2], "00000")
        rb = register_mapping.get(elements[3], "00000")
        rc = register_mapping.get(elements[4], "00000")
        return f"{opcode}{rd}{ra}{rb}{rc}{'0' * 6}"

    elif elements[0] in {"OM2DNN", "OM2P0", "OM2P1", "DNN2OM"}:
        opcode = opcode_mapping[elements[0]]
        rd = register_mapping.get(elements[1], "00000")
        ra = register_mapping.get(elements[2], "00000")
        rb = register_mapping.get(elements[3], "00000")
        rc = register_mapping.get(elements[4], "00000")
        return f"{opcode}{rd}{ra}{rb}{rc}{'0' * 6}"

    elif elements[0] == "BR":
        opcode = opcode_mapping[elements[0]]
        immediate = convert_to_binary(elements[1], 16)
        return f"{opcode}{'0' * 10}{immediate}"

    elif elements[0] == "CBR":
        opcode = opcode_mapping[elements[0]]
        rd = register_mapping.get(elements[1], "00000")
        imm16 = convert_to_binary(elements[2], 16)
        return f"{opcode}{'0' * 5}{rd}{imm16}"

    elif elements[0] in {"SDC", "VSYNC", "END", "HSYNC"}:
        opcode = opcode_mapping[elements[0]]
        return f"{opcode}{'0' * 26}"

    elif elements[0] == "NOP":
        return f"{'0' * 32}"

    return "Unsupported instruction"

# note: Đưa các input features, kernel vào mem theo thứ tự như sau:
# Với input features: ví dụ đầu vào là 32x32x3 (weight x height x depth) và ví dụ chỉ xử lý 4 hàng đầu tiên là 0, 1, 2, 3
# Thứ tự đưa là input 0 -> 3(depth = 0), input 0 -> 3(depth = 1), input 0 -> 3(depth = 2)

# Với kernel: ví dụ một kernel có kích thước là 3x3x3 (wtight x height x depth) thì đưa như sau:
# [31,  2,  3]      [31,  4,  1]        [ 1,  5, 41]
# [10, 11, 12]      [12,  5,  8]        [ 2,  6, 48]
# [ 0,  4, 20]      [22,  9,  7]        [ 0,  1, 15]
# Ví dụ như trên, từ trái sang phải lần lượt là ma trận depth = 0, = 1, = 2
# Với KSP[0], đưa pixel đầu tiên với depth = 0,1,2 vào tại addr 0, 1, 2
# KSP[0] = [31, 31, 1]
# Các KSP[1->8] tương tự
# KSP[1] = [2, 4, 5]
# KSP[2] = [3, 1, 41]
# KSP[3] = [10, 12, 2]
# KSP[4] = [11, 5, 6]
# .....
# KSP[7] = [4, 9, 1]
# KSP[8] = [20, 7, 15]


# Nếu muốn xử lý nhiều filter cùng lúc, giả sử một filter là 3x3x3 -> cần 3x3 = 9 ALU
# Giả sử ta sử dụng ALU[0] -> ALU[8]
# Lúc này ALU[9] sẽ không được dùng (do liên quan đến việc đọc data của ALU[10] trở đi)
# Dùng ALU[10] -> ALU[18] để xử lý filter mới
# Tương tự như vậy, ta bỏ ALU[19] và dùng từ ALU[20]


# Instructions cho mô hình 1 ASIP (hoàn chỉnh)
instructions = {
# Xử lý CONV0
        # Xử lý lặp cho 6 filter  ============================================================================
        0: "MOVLO R8, 6",
        1: "NOP",
            # Xử lý lặp cho 1 filter
            2: "MOVLO R6, 3",                  # vòng lặp cho depth
            3: "NOP",
            4: "MOVHI R1, 0x0001",              # base data
            5: "ADDI R1, R1, 0x0C00",           # base OM addr conv0
            6: "MOVHI R3, 0x0002",              # base DNN addr conv0
            7: "MOVLO R5, 9",                   # vòng lặp cho 1 depth của filter (9 giá trị)
            8: "NOP",
            9: "OM2DNN R1, R2, R3, R4",
            10: "INC R2, R2",
            11: "ADDI R4, R4, 0x0200",
            12: "DEC R5, R5",                   # Giảm vòng lặp
            13: "NOP",                          # nop
            14: "CBR R5, 8",                    # kiểm tra R5 để nhảy về PC = 8
            15: "NOP",
            16: "SUBI R4, R4, 0x1200",          # reset lại offset R4
            17: "SUB R4, R4, R7",
            18: "INC R7, R7",                   # base depth
            19: "NOP",
            20: "ADD R4, R4, R7",               # Tăng depth offset DNN
            21: "DEC R6, R6",
            22: "ADD R1, R0, R0",
            23: "NOP",
            24: "CBR R6, 3",
            25: "NOP",
        26: "DEC R8, R8",
        27: "MOVLO R7, 0",
        28: "ADDI R10, R10, 0x1400",
        29: "ADDI R9, R9, 27",
        30: "ADD R2, R0, R9",
        31: "ADD R4, R0, R10",
        32: "NOP",
        33: "CBR R8, 1",


        # Nạp input features 0 vào IB (hàng 0, 1, 2 - depth = 3)
        34: "MOV R2, R0",               # offset OM
        35: "MOV R4, R0",               # offset DNN
        36: "MOVHI R1, 0x0001",         # base OM
        37: "MOVHI R3, 0x0001",         # offset DNN
            38: "MOVLO R7, 3",
                39: "MOVLO R6, 96",             # R6 = 96
                40: "NOP",
                41: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                42: "INC R2, R2",               # tăng offset
                43: "INC R4, R4",               # tăng offset
                44: "DEC R6, R6",                # giảm số lần lặp
                45: "NOP",
                46: "CBR R6, 40",                # Loop
            47: "ADDI R2, R2, 928",
            48: "DEC R7, R7",
            49: "NOP",
            50: "CBR R7, 39",
        51: "NOP",

        # Nạp bias
        52: "MOVHI R1, 0x0001",
        53: "ADDI R1, R1, 0x0F60",
        54: "MOVHI R3, 0x0003",
        55: "MOV R2, R0",
        56: "MOV R4, R0",
        57: "MOVLO R5, 6",
        58: "NOP",
        59: "OM2DNN R1, R2, R3, R4",
        60: "DEC R5, R5",
        61: "INC R2, R2",
        62: "INC R4, R4",
        63: "NOP",
        64: "CBR R5, 58",
        65: "NOP",



        # Nạp DNN instructions vào DNN mem
        66: "MOV R1, R0",               # base OM
        67: "MOV R2, R0",               # offset OM
        68: "MOVHI R3, 0x0005",         # base DNN
        69: "MOV R4, R0",               # offset DNN
        70: "MOVLO R6, 452",            # Số lượng instructions muốn nạp
        71: "NOP",
        72: "OM2DNN R1, R2, R3, R4",    # Tạo lệnh đọc OM instruction và store vào DNN instruction mem
        73: "INC R2, R2",               # Tăng địa chỉ truy cập OM
        74: "INC R4, R4",               # Tăng địa chỉ truy cập DNN instruction mem
        75: "DEC R6, R6",               # Giảm số lần lặp
        76: "NOP",
        77: "CBR R6, 71",               # Nhảy về địa chỉ 71
        78: "NOP",
        79: "VSYNC",            # Đồng bộ dọc
        80: "SDC",              # Start DNN



        # Nạp input features 0 vào IB (hàng 1, 2, 3, 4 - depth = 3)
        81: "NOP",
        82: "ADDI R2, R0, 32",          # offset OM
        83: "MOV R4, R0",               # offset DNN
        84: "MOVHI R1, 0x0001",         # base OM
        85: "MOVHI R3, 0x0001",         # offset DNN
            86: "MOVLO R7, 3",
            87: "MOVLO R6, 128",
                88: "NOP",
                89: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                90: "INC R2, R2",               # tăng offset
                91: "INC R4, R4",               # tăng offset
                92: "DEC R6, R6",                # giảm số lần lặp
                93: "NOP",
                94: "CBR R6, 88",                # Loop
            95: "ADDI R2, R2, 896",
            96: "DEC R7, R7",
            97: "NOP",
            98: "CBR R7, 87",
        99: "NOP",

        # Chuyển output của conv0 từ OB về OM (16/256 của một lớp)  // Store từ 0x00425000
        # Lưu kết quả của 6 filter
        100: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        101: "MOV R2, R0",
        102: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        103: "ADDI R3, R3, 0x5000",
        104: "MOV R4, R0",
        105: "MOVLO R5, 6",             # Lặp cho 6 filterr
            106: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                107: "NOP",
                108: "DNN2OM R1, R2, R3, R4",
                109: "INC R2, R2",
                110: "INC R4, R4",
                111: "DEC R6, R6",
                112: "NOP",
                113: "CBR R6, 107",
            114: "DEC R5, R5",
            115: "MOV R4, R0",
            116: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            117: "NOP",
            118: "CBR R5, 106",
        119: "NOP",

        # Nạp instruction cho DNN
        120: "MOV R1, R0",               # base OM
        121: "MOVLO R2, 452",               # offset OM
        122: "MOVHI R3, 0x0005",         # base DNN
        123: "MOV R4, R0",               # offset DNN
        124: "MOVLO R6, 469",
            125: "NOP",
            126: "OM2DNN R1, R2, R3, R4",
            127: "INC R2, R2",
            128: "INC R4, R4",
            129: "DEC R6, R6",
            130: "NOP",
            131: "CBR R6, 125",
        132: "NOP",
        133: "VSYNC",          # Đồng bộ dọc
        134: "SDC",            # Start DNN
        135: "NOP",

        # Thực hiện lưu output (32/256) và nạp input features mới (hàng 3, 4, 5, 6)
        # Lưu
        136: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        137: "MOV R2, R0",
        138: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        139: "ADDI R3, R3, 0x5010",
        140: "MOV R4, R0",
        141: "MOVLO R5, 6",             # Lặp cho 6 filterr
            142: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                143: "NOP",
                144: "DNN2OM R1, R2, R3, R4",
                145: "INC R2, R2",
                146: "INC R4, R4",
                147: "DEC R6, R6",
                148: "NOP",
                149: "CBR R6, 143",
            150: "DEC R5, R5",
            151: "MOV R4, R0",
            152: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            153: "NOP",
            154: "CBR R5, 142",
        155: "NOP",
        # Nạp
        156: "ADDI R2, R0, 96",          # offset OM
        157: "MOV R4, R0",               # offset DNN
        158: "MOVHI R1, 0x0001",         # base OM
        159: "MOVHI R3, 0x0001",         # offset DNN
        160: "MOVLO R7, 3",
            161: "MOVLO R6, 128",
                162: "NOP",
                163: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                164: "INC R2, R2",               # tăng offset
                165: "INC R4, R4",               # tăng offset
                166: "DEC R6, R6",                # giảm số lần lặp
                167: "NOP",
                168: "CBR R6, 162",                # Loop
            169: "ADDI R2, R2, 896",
            170: "DEC R7, R7",
            171: "NOP",
            172: "CBR R7, 161",
        173: "NOP",
        174: "VSYNC",
        175: "SDC",
        176: "NOP",

        # Thực hiện lưu output (48/256) và nạp input features mới (hàng 5, 6, 7, 8)
        # Lưu
        177: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        178: "MOV R2, R0",
        179: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        180: "ADDI R3, R3, 0x5020",
        181: "MOV R4, R0",
        182: "MOVLO R5, 6",             # Lặp cho 6 filterr
            183: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                184: "NOP",
                185: "DNN2OM R1, R2, R3, R4",
                186: "INC R2, R2",
                187: "INC R4, R4",
                188: "DEC R6, R6",
                189: "NOP",
                190: "CBR R6, 184",
            191: "DEC R5, R5",
            192: "MOV R4, R0",
            193: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            194: "NOP",
            195: "CBR R5, 183",
        196: "NOP",

        # Nạp
        197: "ADDI R2, R0, 160",          # offset OM
        198: "MOV R4, R0",               # offset DNN
        199: "MOVHI R1, 0x0001",         # base OM
        200: "MOVHI R3, 0x0001",         # offset DNN
        201: "MOVLO R7, 3",
            202: "MOVLO R6, 128",
                203: "NOP",
                204: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                205: "INC R2, R2",               # tăng offset
                206: "INC R4, R4",               # tăng offset
                207: "DEC R6, R6",                # giảm số lần lặp
                208: "NOP",
                209: "CBR R6, 203",                # Loop
            210: "ADDI R2, R2, 896",
            211: "DEC R7, R7",
            212: "NOP",
            213: "CBR R7, 202",
        214: "NOP",
        215: "VSYNC",
        216: "SDC",
        217: "NOP",

        # Thực hiện lưu output (64/256) và nạp input features mới (hàng 7, 8, 9, 10)
        # Lưu
        218: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        219: "MOV R2, R0",
        220: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        221: "ADDI R3, R3, 0x5030",
        222: "MOV R4, R0",
        223: "MOVLO R5, 6",             # Lặp cho 6 filterr
            224: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                225: "NOP",
                226: "DNN2OM R1, R2, R3, R4",
                227: "INC R2, R2",
                228: "INC R4, R4",
                229: "DEC R6, R6",
                230: "NOP",
                231: "CBR R6, 225",
            232: "DEC R5, R5",
            233: "MOV R4, R0",
            234: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            235: "NOP",
            236: "CBR R5, 224",
        237: "NOP",

        # Nạp
        238: "ADDI R2, R0, 224",          # offset OM
        239: "MOV R4, R0",               # offset DNN
        240: "MOVHI R1, 0x0001",         # base OM
        241: "MOVHI R3, 0x0001",         # offset DNN
        242: "MOVLO R7, 3",
            243: "MOVLO R6, 128",
                244: "NOP",
                245: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                246: "INC R2, R2",               # tăng offset
                247: "INC R4, R4",               # tăng offset
                248: "DEC R6, R6",                # giảm số lần lặp
                249: "NOP",
                250: "CBR R6, 244",                # Loop
            251: "ADDI R2, R2, 896",
            252: "DEC R7, R7",
            253: "NOP",
            254: "CBR R7, 243",
        255: "NOP",
        256: "VSYNC",
        257: "SDC",
        258: "NOP",

        # Thực hiện lưu output (80/256) và nạp input features mới (hàng 9, 10, 11, 12)
        # Lưu
        259: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        260: "MOV R2, R0",
        261: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        262: "ADDI R3, R3, 0x5040",
        263: "MOV R4, R0",
        264: "MOVLO R5, 6",             # Lặp cho 6 filterr
            265: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                266: "NOP",
                267: "DNN2OM R1, R2, R3, R4",
                268: "INC R2, R2",
                269: "INC R4, R4",
                270: "DEC R6, R6",
                271: "NOP",
                272: "CBR R6, 266",
            273: "DEC R5, R5",
            274: "MOV R4, R0",
            275: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            276: "NOP",
            277: "CBR R5, 265",
        278: "NOP",

        # Nạp
        279: "ADDI R2, R0, 288",          # offset OM
        280: "MOV R4, R0",               # offset DNN
        281: "MOVHI R1, 0x0001",         # base OM
        282: "MOVHI R3, 0x0001",         # offset DNN
        283: "MOVLO R7, 3",
            284: "MOVLO R6, 128",
                285: "NOP",
                286: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                287: "INC R2, R2",               # tăng offset
                288: "INC R4, R4",               # tăng offset
                289: "DEC R6, R6",                # giảm số lần lặp
                290: "NOP",
                291: "CBR R6, 285",                # Loop
            292: "ADDI R2, R2, 896",
            293: "DEC R7, R7",
            294: "NOP",
            295: "CBR R7, 284",
        296: "NOP",
        297: "VSYNC",
        298: "SDC",
        299: "NOP",

        # Thực hiện lưu output (96/256) (hàng 11, 12, 13, 14)
        # Lưu
        300: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        301: "MOV R2, R0",
        302: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        303: "ADDI R3, R3, 0x5050",
        304: "MOV R4, R0",
        305: "MOVLO R5, 6",             # Lặp cho 6 filterr
            306: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                307: "NOP",
                308: "DNN2OM R1, R2, R3, R4",
                309: "INC R2, R2",
                310: "INC R4, R4",
                311: "DEC R6, R6",
                312: "NOP",
                313: "CBR R6, 307",
            314: "DEC R5, R5",
            315: "MOV R4, R0",
            316: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            317: "NOP",
            318: "CBR R5, 306",
        319: "NOP",

        # Nạp
        320: "ADDI R2, R0, 352",          # offset OM
        321: "MOV R4, R0",               # offset DNN
        322: "MOVHI R1, 0x0001",         # base OM
        323: "MOVHI R3, 0x0001",         # offset DNN
        324: "MOVLO R7, 3",
            325: "MOVLO R6, 128",
                326: "NOP",
                327: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                328: "INC R2, R2",               # tăng offset
                329: "INC R4, R4",               # tăng offset
                330: "DEC R6, R6",                # giảm số lần lặp
                331: "NOP",
                332: "CBR R6, 326",                # Loop
            333: "ADDI R2, R2, 896",
            334: "DEC R7, R7",
            335: "NOP",
            336: "CBR R7, 325",
        337: "NOP",
        338: "VSYNC",
        339: "SDC",
        340: "NOP",

        # Thực hiện lưu output (112/256) (hàng 13, 14, 15, 16)
        # Lưu
        341: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        342: "MOV R2, R0",
        343: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        344: "ADDI R3, R3, 0x5060",
        345: "MOV R4, R0",
        346: "MOVLO R5, 6",             # Lặp cho 6 filterr
            347: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                348: "NOP",
                349: "DNN2OM R1, R2, R3, R4",
                350: "INC R2, R2",
                351: "INC R4, R4",
                352: "DEC R6, R6",
                353: "NOP",
                354: "CBR R6, 348",
            355: "DEC R5, R5",
            356: "MOV R4, R0",
            357: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            358: "NOP",
            359: "CBR R5, 347",
        360: "NOP",

        # Nạp
        361: "ADDI R2, R0, 416",          # offset OM
        362: "MOV R4, R0",               # offset DNN
        363: "MOVHI R1, 0x0001",         # base OM
        364: "MOVHI R3, 0x0001",         # offset DNN
        365: "MOVLO R7, 3",
            366: "MOVLO R6, 128",
                367: "NOP",
                368: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                369: "INC R2, R2",               # tăng offset
                370: "INC R4, R4",               # tăng offset
                371: "DEC R6, R6",                # giảm số lần lặp
                372: "NOP",
                373: "CBR R6, 367",                # Loop
            374: "ADDI R2, R2, 896",
            375: "DEC R7, R7",
            376: "NOP",
            377: "CBR R7, 366",
        378: "NOP",
        379: "VSYNC",
        380: "SDC",
        381: "NOP",

        # Thực hiện lưu output (128/256) (hàng 15, 16, 17, 18)
        # Lưu
        382: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        383: "MOV R2, R0",
        384: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        385: "ADDI R3, R3, 0x5070",
        386: "MOV R4, R0",
        387: "MOVLO R5, 6",             # Lặp cho 6 filterr
            388: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                389: "NOP",
                390: "DNN2OM R1, R2, R3, R4",
                391: "INC R2, R2",
                392: "INC R4, R4",
                393: "DEC R6, R6",
                394: "NOP",
                395: "CBR R6, 389",
            396: "DEC R5, R5",
            397: "MOV R4, R0",
            398: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            399: "NOP",
            400: "CBR R5, 388",
        401: "NOP",

        # Nạp
        402: "ADDI R2, R0, 480",          # offset OM
        403: "MOV R4, R0",               # offset DNN
        404: "MOVHI R1, 0x0001",         # base OM
        405: "MOVHI R3, 0x0001",         # offset DNN
        406: "MOVLO R7, 3",
            407: "MOVLO R6, 128",
                408: "NOP",
                409: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                410: "INC R2, R2",               # tăng offset
                411: "INC R4, R4",               # tăng offset
                412: "DEC R6, R6",                # giảm số lần lặp
                413: "NOP",
                414: "CBR R6, 408",                # Loop
            415: "ADDI R2, R2, 896",
            416: "DEC R7, R7",
            417: "NOP",
            418: "CBR R7, 407",
        419: "NOP",
        420: "VSYNC",
        421: "SDC",
        422: "NOP",

        # Thực hiện lưu output (144/256) (hàng 17, 18, 19, 20)
        # Lưu
        423: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        424: "MOV R2, R0",
        425: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        426: "ADDI R3, R3, 0x5080",
        427: "MOV R4, R0",
        428: "MOVLO R5, 6",             # Lặp cho 6 filterr
            429: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                430: "NOP",
                431: "DNN2OM R1, R2, R3, R4",
                432: "INC R2, R2",
                433: "INC R4, R4",
                434: "DEC R6, R6",
                435: "NOP",
                436: "CBR R6, 430",
            437: "DEC R5, R5",
            438: "MOV R4, R0",
            439: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            440: "NOP",
            441: "CBR R5, 429",
        442: "NOP",

        # Nạp
        443: "ADDI R2, R0, 544",          # offset OM
        444: "MOV R4, R0",               # offset DNN
        445: "MOVHI R1, 0x0001",         # base OM
        446: "MOVHI R3, 0x0001",         # offset DNN
        447: "MOVLO R7, 3",
            448: "MOVLO R6, 128",
                449: "NOP",
                450: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                451: "INC R2, R2",               # tăng offset
                452: "INC R4, R4",               # tăng offset
                453: "DEC R6, R6",                # giảm số lần lặp
                454: "NOP",
                455: "CBR R6, 449",                # Loop
            456: "ADDI R2, R2, 896",
            457: "DEC R7, R7",
            458: "NOP",
            459: "CBR R7, 448",
        460: "NOP",
        461: "VSYNC",
        462: "SDC",
        463: "NOP",

        # Thực hiện lưu output (160/256) (hàng 19, 20, 21, 22)
        # Lưu
        464: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        465: "MOV R2, R0",
        466: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        467: "ADDI R3, R3, 0x5090",
        468: "MOV R4, R0",
        469: "MOVLO R5, 6",             # Lặp cho 6 filterr
            470: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                471: "NOP",
                472: "DNN2OM R1, R2, R3, R4",
                473: "INC R2, R2",
                474: "INC R4, R4",
                475: "DEC R6, R6",
                476: "NOP",
                477: "CBR R6, 471",
            478: "DEC R5, R5",
            479: "MOV R4, R0",
            480: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            481: "NOP",
            482: "CBR R5, 470",
        483: "NOP",

        # Nạp
        484: "ADDI R2, R0, 608",          # offset OM
        485: "MOV R4, R0",               # offset DNN
        486: "MOVHI R1, 0x0001",         # base OM
        487: "MOVHI R3, 0x0001",         # offset DNN
        488: "MOVLO R7, 3",
            489: "MOVLO R6, 128",
                490: "NOP",
                491: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                492: "INC R2, R2",               # tăng offset
                493: "INC R4, R4",               # tăng offset
                494: "DEC R6, R6",                # giảm số lần lặp
                495: "NOP",
                496: "CBR R6, 490",                # Loop
            497: "ADDI R2, R2, 896",
            498: "DEC R7, R7",
            499: "NOP",
            500: "CBR R7, 489",
        501: "NOP",
        502: "VSYNC",
        503: "SDC",
        504: "NOP",

        # Thực hiện lưu output (176/256) (hàng 21, 22, 23, 24)
        # Lưu
        505: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        506: "MOV R2, R0",
        507: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        508: "ADDI R3, R3, 0x50A0",
        509: "MOV R4, R0",
        510: "MOVLO R5, 6",             # Lặp cho 6 filterr
            511: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                512: "NOP",
                513: "DNN2OM R1, R2, R3, R4",
                514: "INC R2, R2",
                515: "INC R4, R4",
                516: "DEC R6, R6",
                517: "NOP",
                518: "CBR R6, 512",
            519: "DEC R5, R5",
            520: "MOV R4, R0",
            521: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            522: "NOP",
            523: "CBR R5, 511",
        524: "NOP",

        # Nạp
        525: "ADDI R2, R0, 672",          # offset OM
        526: "MOV R4, R0",               # offset DNN
        527: "MOVHI R1, 0x0001",         # base OM
        528: "MOVHI R3, 0x0001",         # offset DNN
        529: "MOVLO R7, 3",
            530: "MOVLO R6, 128",
                531: "NOP",
                532: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                533: "INC R2, R2",               # tăng offset
                534: "INC R4, R4",               # tăng offset
                535: "DEC R6, R6",                # giảm số lần lặp
                536: "NOP",
                537: "CBR R6, 531",                # Loop
            538: "ADDI R2, R2, 896",
            539: "DEC R7, R7",
            540: "NOP",
            541: "CBR R7, 530",
        542: "NOP",
        543: "VSYNC",
        544: "SDC",
        545: "NOP",

        # Thực hiện lưu output (192/256) (hàng 23, 24, 25, 26)
        # Lưu
        546: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        547: "MOV R2, R0",
        548: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        549: "ADDI R3, R3, 0x50B0",
        550: "MOV R4, R0",
        551: "MOVLO R5, 6",             # Lặp cho 6 filterr
            552: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                553: "NOP",
                554: "DNN2OM R1, R2, R3, R4",
                555: "INC R2, R2",
                556: "INC R4, R4",
                557: "DEC R6, R6",
                558: "NOP",
                559: "CBR R6, 553",
            560: "DEC R5, R5",
            561: "MOV R4, R0",
            562: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            563: "NOP",
            564: "CBR R5, 552",
        565: "NOP",

        # Nạp
        566: "ADDI R2, R0, 736",          # offset OM
        567: "MOV R4, R0",               # offset DNN
        568: "MOVHI R1, 0x0001",         # base OM
        569: "MOVHI R3, 0x0001",         # offset DNN
        570: "MOVLO R7, 3",
            571: "MOVLO R6, 128",
                572: "NOP",
                573: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                574: "INC R2, R2",               # tăng offset
                575: "INC R4, R4",               # tăng offset
                576: "DEC R6, R6",                # giảm số lần lặp
                577: "NOP",
                578: "CBR R6, 572",                # Loop
            579: "ADDI R2, R2, 896",
            580: "DEC R7, R7",
            581: "NOP",
            582: "CBR R7, 571",
        583: "NOP",
        584: "VSYNC",
        585: "SDC",
        586: "NOP",

        # Thực hiện lưu output (208/256) (hàng 25, 26, 27, 28)
        # Lưu
        587: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        588: "MOV R2, R0",
        589: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        590: "ADDI R3, R3, 0x50C0",
        591: "MOV R4, R0",
        592: "MOVLO R5, 6",             # Lặp cho 6 filterr
            593: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                594: "NOP",
                595: "DNN2OM R1, R2, R3, R4",
                596: "INC R2, R2",
                597: "INC R4, R4",
                598: "DEC R6, R6",
                599: "NOP",
                600: "CBR R6, 594",
            601: "DEC R5, R5",
            602: "MOV R4, R0",
            603: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            604: "NOP",
            605: "CBR R5, 593",
        606: "NOP",

        # Nạp
        607: "ADDI R2, R0, 800",          # offset OM
        608: "MOV R4, R0",               # offset DNN
        609: "MOVHI R1, 0x0001",         # base OM
        610: "MOVHI R3, 0x0001",         # offset DNN
        611: "MOVLO R7, 3",
            612: "MOVLO R6, 128",
                613: "NOP",
                614: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                615: "INC R2, R2",               # tăng offset
                616: "INC R4, R4",               # tăng offset
                617: "DEC R6, R6",                # giảm số lần lặp
                618: "NOP",
                619: "CBR R6, 613",                # Loop
            620: "ADDI R2, R2, 896",
            621: "DEC R7, R7",
            622: "NOP",
            623: "CBR R7, 612",
        624: "NOP",
        625: "VSYNC",
        626: "SDC",
        627: "NOP",

        # Thực hiện lưu output (224/256) (hàng 27, 28, 29, 30)
        # Lưu
        628: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        629: "MOV R2, R0",
        630: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        631: "ADDI R3, R3, 0x50D0",
        632: "MOV R4, R0",
        633: "MOVLO R5, 6",             # Lặp cho 6 filterr
            634: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                635: "NOP",
                636: "DNN2OM R1, R2, R3, R4",
                637: "INC R2, R2",
                638: "INC R4, R4",
                639: "DEC R6, R6",
                640: "NOP",
                641: "CBR R6, 635",
            642: "DEC R5, R5",
            643: "MOV R4, R0",
            644: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            645: "NOP",
            646: "CBR R5, 634",
        647: "NOP",

        # Nạp
        648: "ADDI R2, R0, 864",          # offset OM
        649: "MOV R4, R0",               # offset DNN
        650: "MOVHI R1, 0x0001",         # base OM
        651: "MOVHI R3, 0x0001",         # offset DNN
        652: "MOVLO R7, 3",
            653: "MOVLO R6, 128",
                654: "NOP",
                655: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                656: "INC R2, R2",               # tăng offset
                657: "INC R4, R4",               # tăng offset
                658: "DEC R6, R6",                # giảm số lần lặp
                659: "NOP",
                660: "CBR R6, 654",                # Loop
            661: "ADDI R2, R2, 896",
            662: "DEC R7, R7",
            663: "NOP",
            664: "CBR R7, 653",
        665: "NOP",
        666: "VSYNC",
        667: "SDC",
        668: "NOP",

        # Thực hiện lưu output (240/256) (hàng 29, 30, 31) + Nạp lệnh
        # Lưu
        669: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        670: "MOV R2, R0",
        671: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        672: "ADDI R3, R3, 0x50E0",
        673: "MOV R4, R0",
        674: "MOVLO R5, 6",             # Lặp cho 6 filterr
            675: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                676: "NOP",
                677: "DNN2OM R1, R2, R3, R4",
                678: "INC R2, R2",
                679: "INC R4, R4",
                680: "DEC R6, R6",
                681: "NOP",
                682: "CBR R6, 676",
            683: "DEC R5, R5",
            684: "MOV R4, R0",
            685: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            686: "NOP",
            687: "CBR R5, 675",
        688: "NOP",

        # Nạp data
        689: "ADDI R2, R0, 928",          # offset OM
        690: "MOV R4, R0",               # offset DNN
        691: "MOVHI R1, 0x0001",         # base OM
        692: "MOVHI R3, 0x0001",         # offset DNN
        693: "MOVLO R7, 3",
            694: "MOVLO R6, 96",
                695: "NOP",
                696: "OM2DNN R1, R2, R3, R4",      # tạo lệnh
                697: "INC R2, R2",               # tăng offset
                698: "INC R4, R4",               # tăng offset
                699: "DEC R6, R6",                # giảm số lần lặp
                700: "NOP",
                701: "CBR R6, 695",                # Loop
            702: "ADDI R2, R2, 896",
            703: "DEC R7, R7",
            704: "NOP",
            705: "CBR R7, 694",
        706: "NOP",

        # Nạp instruction
        707: "MOV R1, R0",               # base OM
        708: "MOVLO R2, 921",               # offset OM
        709: "MOVHI R3, 0x0005",         # base DNN
        710: "MOVLO R4, 234",               # offset DNN
        711: "MOVLO R6, 218",
            712: "NOP",
            713: "OM2DNN R1, R2, R3, R4",
            714: "INC R2, R2",
            715: "INC R4, R4",
            716: "DEC R6, R6",
            717: "NOP",
            718: "CBR R6, 712",
        719: "NOP",
        720: "VSYNC",          # Đồng bộ dọc
        721: "SDC",            # Start DNN
        722: "NOP",

        # Thực hiện lưu output (256/256)
        # Lưu
        723: "MOVHI R1, 0x0003",        # Tạo địa chỉ truy cập OB
        724: "MOV R2, R0",
        725: "MOVHI R3, 0x0042",        # Tạo địa chỉ truy cập OM
        726: "ADDI R3, R3, 0x50F0",
        727: "MOV R4, R0",
        728: "MOVLO R5, 6",             # Lặp cho 6 filterr
            729: "MOVLO, R6, 16",       # 1 filter thì lưu 16 output
                730: "NOP",
                731: "DNN2OM R1, R2, R3, R4",
                732: "INC R2, R2",
                733: "INC R4, R4",
                734: "DEC R6, R6",
                735: "NOP",
                736: "CBR R6, 730",
            737: "DEC R5, R5",
            738: "MOV R4, R0",
            739: "ADDI R3, R3, 256",        # 1 filter thì sẽ có 16x16=256 output -> di chuyển đến địa chỉ để lưu kết quả cho filter tiếp theo
            740: "NOP",
            741: "CBR R5, 729",
        742: "NOP",
# FINISH CONV0


# 425000
# Xử lý DENSE0
    # Nạp input feature vào 64 IB (input dense0 = output conv0)
    743: "MOVHI R1, 0x0042",                # Tạo địa chỉ truy cập OM tại địa chỉ 0x00425000
    744: "ADDI R2, R0, 0x5000",
    745: "MOV R4, R0",
    746: "MOVLO R5, 24",                    # Do conv0 có 16x16x6 = 1536 output và ta sử dụng 64 ALU cùng lúc -> lặp 24 lần
        747: "MOVLO R6, 64",                # Lặp để ghi 64 data
        748: "MOVHI R3, 0x0001",            # Tạo địa chỉ truy cập IB
            749: "NOP",
            750: "OM2DNN R1, R2, R3, R4",
            751: "DEC R6, R6",              # Giảm số lần lặp (theo số lượng IB)
            752: "INC R2, R2",              # Tăng địa chỉ truy cập OM
            753: "ADDI R3, R3, 512",        # Tăng địa chỉ truy cập DNN (tăng 512 để sang IB kế tiếp)
            754: "NOP",
            755: "CBR R6, 749",
        756: "NOP",
        757: "INC R4, R4",                  # Tăng địa chỉ truy cập DNN (tăng theo độ sâu của một IB)
        758: "DEC R5, R5",                  # Giảm số lần lặp (theo độ sâu)
        759: "NOP",
        760: "CBR R5, 747",
        761: "NOP",

    # Nạp weights vào 64 KSP
    762: "MOVHI R1, 0x0001",                # Tạo địa chỉ truy cập OM tại địa chỉ 0x000133A0
    763: "ADDI R2, R0, 0x33A0",
    764: "MOV R4, R0",
    765: "MOVLO R5, 240",                    # Do conv0 có 16x16x6 = 1536 output và ta sử dụng 64 ALU cùng lúc -> lặp 24 lần
        766: "MOVLO R6, 64",                # Lặp để ghi 64 data
        767: "MOVHI R3, 0x0002",            # Tạo địa chỉ truy cập IB
            768: "NOP",
            769: "OM2DNN R1, R2, R3, R4",
            770: "DEC R6, R6",              # Giảm số lần lặp (theo số lượng IB)
            771: "INC R2, R2",              # Tăng địa chỉ truy cập OM
            772: "ADDI R3, R3, 512",        # Tăng địa chỉ truy cập DNN (tăng 512 để sang IB kế tiếp)
            773: "NOP",
            774: "CBR R6, 768",
        775: "NOP",
        776: "INC R4, R4",                  # Tăng địa chỉ truy cập DNN (tăng theo độ sâu của một IB)
        777: "DEC R5, R5",                  # Giảm số lần lặp (theo độ sâu)
        778: "NOP",
        779: "CBR R5, 766",
        780: "NOP",

    # Nạp biases vào BSP
    781: "MOVHI R1, 0x0041",
    782: "ADDI R1, R1, 0x33A0",
    783: "MOVHI R3, 0x0003",
    784: "MOV R2, R0",
    785: "MOV R4, R0",
    786: "MOVLO R5, 10",
        787: "NOP",
        788: "OM2DNN R1, R2, R3, R4",
        789: "DEC R5, R5",
        790: "INC R2, R2",
        791: "INC R4, R4",
        792: "NOP",
        793: "CBR R5, 787",
    794: "NOP",

    # Nạp lệnh thực thi
    795: "MOV R1, R0",               # base OM
    796: "MOVLO R2, 1140",               # offset OM
    797: "MOVHI R3, 0x0005",         # base DNN
    798: "MOV R4, R0",               # offset DNN
    799: "MOVLO R6, 254",             # Số lượng lệnh muốn nạp
        800: "NOP",
        801: "OM2DNN R1, R2, R3, R4",
        802: "INC R2, R2",
        803: "INC R4, R4",
        804: "DEC R6, R6",
        805: "NOP",
        806: "CBR R6, 800",
    807: "NOP",
    808: "VSYNC",          # Đồng bộ dọc
    809: "SDC",            # Start DNN
    810: "NOP",


# FINISH DENSE0

    811: "NOP",
    812: "NOP",
    813: "MOV R1, R0",
    814: "MOV R2, R0",
    815: "MOV R3, R0",
    816: "MOV R4, R0",
    817: "MOV R5, R0",
    818: "MOV R6, R0",
    819: "MOV R7, R0",
    820: "MOV R8, R0",
    821: "MOV R9, R0",
    822: "MOV R10, R0",
    823: "MOV R11, R0",
    824: "MOV R12, R0",
    825: "MOV R13, R0",
    826: "MOV R14, R0",
    827: "MOV R15, R0",
    828: "MOV R16, R0",
    829: "MOV R17, R0",
    830: "MOV R18, R0",
    831: "MOV R19, R0",
    832: "MOV R20, R0",
    833: "MOV R21, R0",
    834: "MOV R22, R0",
    835: "MOV R23, R0",
    836: "MOV R24, R0",
    837: "MOV R25, R0",
    838: "MOV R26, R0",
    839: "MOV R27, R0",
    840: "MOV R28, R0",
    841: "MOV R29, R0",
    842: "MOV R30, R0",
    843: "MOV R31, R0",

    844: "END",

}
########################################################

# Instructions cho mô hình 1-1 (ví dụ) (chưa hoàn chỉnh)
instructions_one_one_1 = {
    0: "MOVLO R8, 6",
    1: "NOP",
    # Xử lý lặp cho 1 filter
    2: "MOVLO R6, 3",  # vòng lặp cho depth
    3: "NOP",
    4: "MOVHI R1, 0x0001",  # base data
    5: "ADDI R1, R1, 0x0C00",  # base OM addr conv0
    6: "MOVHI R3, 0x0002",  # base DNN addr conv0
    7: "MOVLO R5, 9",  # vòng lặp cho 1 depth của filter (9 giá trị)
    8: "NOP",
    9: "OM2DNN R1, R2, R3, R4",
    10: "INC R2, R2",
    11: "ADDI R4, R4, 0x0200",
    12: "DEC R5, R5",  # Giảm vòng lặp
    13: "NOP",  # nop
    14: "CBR R5, 8",  # kiểm tra R5 để nhảy về PC = 8
    15: "NOP",
    16: "SUBI R4, R4, 0x1200",  # reset lại offset R4
    17: "SUB R4, R4, R7",
    18: "INC R7, R7",  # base depth
    19: "NOP",
    20: "ADD R4, R4, R7",  # Tăng depth offset DNN
    21: "DEC R6, R6",
    22: "ADD R1, R0, R0",
    23: "NOP",
    24: "CBR R6, 3",
    25: "NOP",
    26: "DEC R8, R8",
    27: "MOVLO R7, 0",
    28: "ADDI R10, R10, 0x1400",
    29: "ADDI R9, R9, 27",
    30: "ADD R2, R0, R9",
    31: "ADD R4, R0, R10",
    32: "NOP",
    33: "CBR R8, 1",

    # Nạp input features 0 vào IB (hàng 0, 1, 2 - depth = 3)
    34: "MOV R2, R0",  # offset OM
    35: "MOV R4, R0",  # offset DNN
    36: "MOVHI R1, 0x0001",  # base OM
    37: "MOVHI R3, 0x0001",  # offset DNN
    38: "MOVLO R7, 3",
    39: "MOVLO R6, 96",  # R6 = 96
    40: "NOP",
    41: "OM2DNN R1, R2, R3, R4",  # tạo lệnh
    42: "INC R2, R2",  # tăng offset
    43: "INC R4, R4",  # tăng offset
    44: "DEC R6, R6",  # giảm số lần lặp
    45: "NOP",
    46: "CBR R6, 40",  # Loop
    47: "ADDI R2, R2, 928",
    48: "DEC R7, R7",
    49: "NOP",
    50: "CBR R7, 39",
    51: "NOP",

    # Nạp bias
    52: "MOVHI R1, 0x0001",
    53: "ADDI R1, R1, 0x0F60",
    54: "MOVHI R3, 0x0003",
    55: "MOV R2, R0",
    56: "MOV R4, R0",
    57: "MOVLO R5, 6",
    58: "NOP",
    59: "OM2DNN R1, R2, R3, R4",
    60: "DEC R5, R5",
    61: "INC R2, R2",
    62: "INC R4, R4",
    63: "NOP",
    64: "CBR R5, 58",
    65: "NOP",

    # Nạp DNN instructions vào DNN mem
    66: "MOV R1, R0",  # base OM
    67: "MOV R2, R0",  # offset OM
    68: "MOVHI R3, 0x0005",  # base DNN
    69: "MOV R4, R0",  # offset DNN
    70: "MOVLO R6, 452",  # Số lượng instructions muốn nạp
    71: "NOP",
    72: "OM2DNN R1, R2, R3, R4",  # Tạo lệnh đọc OM instruction và store vào DNN instruction mem
    73: "INC R2, R2",  # Tăng địa chỉ truy cập OM
    74: "INC R4, R4",  # Tăng địa chỉ truy cập DNN instruction mem
    75: "DEC R6, R6",  # Giảm số lần lặp
    76: "NOP",
    77: "CBR R6, 71",  # Nhảy về địa chỉ 71
    78: "NOP",
    79: "VSYNC",  # Đồng bộ dọc
    80: "SDC",  # Start DNN
    81: "HSYNC",                # Nếu vẫn tiếp tục nạp dữ liệu và cho DNN core chạy thì chỗ này không được để lệnh HSYNC, nếu không sẽ chuyển sang state đồng bộ chuyển data
    # Nếu là HSYNC thì vô stage TRANSFER
    82: "MOVHI R1, 0x0001",
    83: "MOVLO R2, 11",
    84: "MOVHI R3, 0x0002",
    85: "MOVLO R4, 2",
    86: "NOP",
    87: "NOP",
    88: "OM2P0 R1, R2, R3, R4",     # chuyển data(tại stage transfer từ OM1 0x0001000B sang OM2 0x00020002
    89: "INC R2, R2",
    90: "INC R4, R4",
    91: "NOP",
    92: "OM2P0 R1, R2, R3, R4",  # chuyển data(tại stage TRANSFER từ OM1 0x0001000C sang OM2 0x00020003
    93: "HSYNC",
    # Kết thúc stage TRANSFER
    94: "END"
    # 88: "NOP",
    # 89: "NOP",
    # 90:
}

instructions_one_one_2 = {
0: "MOVLO R8, 6",
    1: "NOP",
    # Xử lý lặp cho 1 filter
    2: "MOVLO R6, 3",  # vòng lặp cho depth
    3: "NOP",
    4: "MOVHI R1, 0x0001",  # base data
    5: "ADDI R1, R1, 0x0C00",  # base OM addr conv0
    6: "MOVHI R3, 0x0002",  # base DNN addr conv0
    7: "MOVLO R5, 9",  # vòng lặp cho 1 depth của filter (9 giá trị)
    8: "NOP",
    9: "OM2DNN R1, R2, R3, R4",
    10: "INC R2, R2",
    11: "ADDI R4, R4, 0x0200",
    12: "DEC R5, R5",  # Giảm vòng lặp
    13: "NOP",  # nop
    14: "CBR R5, 8",  # kiểm tra R5 để nhảy về PC = 8
    15: "NOP",
    16: "SUBI R4, R4, 0x1200",  # reset lại offset R4
    17: "SUB R4, R4, R7",
    18: "INC R7, R7",  # base depth
    19: "NOP",
    20: "ADD R4, R4, R7",  # Tăng depth offset DNN
    21: "DEC R6, R6",
    22: "ADD R1, R0, R0",
    23: "NOP",
    24: "CBR R6, 3",
    25: "NOP",
    26: "DEC R8, R8",
    27: "MOVLO R7, 0",
    28: "ADDI R10, R10, 0x1400",
    29: "ADDI R9, R9, 27",
    30: "ADD R2, R0, R9",
    31: "ADD R4, R0, R10",
    32: "NOP",
    33: "CBR R8, 1",

    # Nạp input features 0 vào IB (hàng 0, 1, 2 - depth = 3)
    34: "MOV R2, R0",  # offset OM
    35: "MOV R4, R0",  # offset DNN
    36: "MOVHI R1, 0x0001",  # base OM
    37: "MOVHI R3, 0x0001",  # offset DNN
    38: "MOVLO R7, 3",
    39: "MOVLO R6, 96",  # R6 = 96
    40: "NOP",
    41: "OM2DNN R1, R2, R3, R4",  # tạo lệnh
    42: "INC R2, R2",  # tăng offset
    43: "INC R4, R4",  # tăng offset
    44: "DEC R6, R6",  # giảm số lần lặp
    45: "NOP",
    46: "CBR R6, 40",  # Loop
    47: "ADDI R2, R2, 928",
    48: "DEC R7, R7",
    49: "NOP",
    50: "CBR R7, 39",
    51: "NOP",

    # Nạp bias
    52: "MOVHI R1, 0x0001",
    53: "ADDI R1, R1, 0x0F60",
    54: "MOVHI R3, 0x0003",
    55: "MOV R2, R0",
    56: "MOV R4, R0",
    57: "MOVLO R5, 6",
    58: "NOP",
    59: "OM2DNN R1, R2, R3, R4",
    60: "DEC R5, R5",
    61: "INC R2, R2",
    62: "INC R4, R4",
    63: "NOP",
    64: "CBR R5, 58",
    65: "NOP",

    # Nạp DNN instructions vào DNN mem
    66: "MOV R1, R0",  # base OM
    67: "MOV R2, R0",  # offset OM
    68: "MOVHI R3, 0x0005",  # base DNN
    69: "MOV R4, R0",  # offset DNN
    70: "MOVLO R6, 452",  # Số lượng instructions muốn nạp
    71: "NOP",
    72: "OM2DNN R1, R2, R3, R4",  # Tạo lệnh đọc OM instruction và store vào DNN instruction mem
    73: "INC R2, R2",  # Tăng địa chỉ truy cập OM
    74: "INC R4, R4",  # Tăng địa chỉ truy cập DNN instruction mem
    75: "DEC R6, R6",  # Giảm số lần lặp
    76: "NOP",
    77: "CBR R6, 71",  # Nhảy về địa chỉ 71
    79: "NOP",
    80: "NOP",
    81: "NOP",
    82: "NOP",
    83: "NOP",
    84: "NOP",
    85: "VSYNC",  # Đồng bộ dọc
    86: "SDC",  # Start DNN
    87: "HSYNC",
    88: "NOP",
    89: "NOP",
    90: "NOP",
    91: "HSYNC",
    92: "END"
}
########################################################
# Đường dẫn file txt
output_file_path = "testfile/controller_instruction/output_instructions_ASIP_1.txt"
# Mở file ở chế độ ghi
with open(output_file_path, "w") as file:
    for PC, instruction in instructions_one_one_1.items():      # Chọn mảng instructions
        # Xử lý để chuyển instruction sang dạng binary
        instruction_binary = pre_processing(instruction)
        # Ghi vào file
        file.write(f"{instruction_binary}\n")