def compile_slot1(slot):
    opcode_slot1 = slot[0]
    offset_slot1 = slot[1]
    opcode_slot1_binary = ''
    offset_slot1_binary = ''
    if opcode_slot1 == 'run':
        opcode_slot1_binary = '00'
    elif opcode_slot1 == 'sbp':
        opcode_slot1_binary = '01'
    elif opcode_slot1 == 'sof':
        opcode_slot1_binary = '10'
    elif opcode_slot1 == 'sit':
        opcode_slot1_binary = '11'
    offset_slot1_binary = format(int(offset_slot1), '09b')
    slot1_binary = opcode_slot1_binary + offset_slot1_binary
    return slot1_binary

def compile_slot2(slot):
    if slot[0] == 'add':
        new_base_addr_binary = '1'
    elif slot[0] == 'nadd':
        new_base_addr_binary = '0'

    base_addr_read_IB_binary    = format(int(slot[1]), '010b')
    base_addr_read_KSP_binary   = format(int(slot[2]), '010b')
    base_addr_write_OSP_binary  = format(int(slot[3]), '010b')
    base_addr_read_OSP_binary   = format(int(slot[4]), '010b')
    base_addr_write_OB_binary   = format(int(slot[5]), '010b')
    base_addr_read_OB_binary    = format(int(slot[6]), '010b')
    base_addr_read_BSP_binary   = format(int(slot[7]), '010b')
    base_addr_write_FCSP_binary = format(int(slot[8]), '010b')
    base_addr_read_FCSP_binary  = format(int(slot[9]), '010b')

    slot2_binary = (new_base_addr_binary
                + base_addr_read_IB_binary
                + base_addr_read_KSP_binary
                + base_addr_write_OSP_binary
                + base_addr_read_OSP_binary
                + base_addr_write_OB_binary
                + base_addr_read_OB_binary
                + base_addr_read_BSP_binary
                + base_addr_write_FCSP_binary
                + base_addr_read_FCSP_binary)
    return(slot2_binary)

def compile_slot3(slot):
    opcode_slot3_binary = ''
    select_slot3_binary = format(int(slot[1]), '08b')
    if slot[0] == 'mld0':                   # not load
        opcode_slot3_binary = '000'
    elif slot[0] == 'mld1':                 # load from IB
        opcode_slot3_binary = '001'
    elif slot[0] == 'mld2':                 # load from IB and KSP
        opcode_slot3_binary = '010'
    elif slot[0] == 'mld3':                 # load form IB and OSP
        opcode_slot3_binary = '011'
    elif slot[0] == 'mld4':                 # load from IB, KSP and OSP
        opcode_slot3_binary = '100'
    elif slot[0] == 'mld5':                 # load from OSP and BSP
        opcode_slot3_binary = '101'
    elif slot[0] == 'mld6':                 # load from BSP and FCSP
        opcode_slot3_binary = '110'
    elif slot[0] == 'mld7':                 # load from OSP, BSP and FCSP
        opcode_slot3_binary = '111'
    slot3_binary = opcode_slot3_binary + select_slot3_binary
    return slot3_binary

def compile_slot4(slot):
    src_mult1_bin = format(int(slot[0]), '02b')
    src_mult2_bin = format(int(slot[1]), '01b')
    src_acc_bin = format(int(slot[2]), '02b')
    src_add_bias = format(int(slot[3]), '01b')
    slot4_binary = src_mult1_bin + src_mult2_bin + src_acc_bin + src_add_bias
    return slot4_binary

def compile_slot5(slot):
    sel_lut_bin = format(int(slot[0]), '01b')
    sel_NOA_bin = format(int(slot[1]), '08b')
    slot5_binary = sel_lut_bin + sel_NOA_bin
    return slot5_binary

def compile_slot6(slot):
    src_max_bin = format(int(slot[0]), '03b')
    sel_POA_bin = format(int(slot[1]), '08b')
    sel_adder_bin = format(int(slot[2]), '01b')
    slot6_binary = src_max_bin + sel_POA_bin + sel_adder_bin
    return slot6_binary

def compile_slot7(slot):
    en_store_bin = ''
    if slot[0] == 'mst0':           # No store
        en_store_bin = '000'
    elif slot[0] == 'mst1':         # store OB
        en_store_bin = '001'
    elif slot[0] == 'mst2':         # store OSP
        en_store_bin = '010'
    elif slot[0] == 'mst3':         # store FCSP
        en_store_bin = '011'
    elif slot[0] == 'mst4':         # store OB and OSP
        en_store_bin = '100'
    elif slot[0] == 'mst5':         # store OB and FCSP
        en_store_bin = '101'
    elif slot[0] == 'mst6':         # store OSP and FCSP
        en_store_bin = '110'
    elif slot[0] == 'mst7':         # store all
        en_store_bin = '111'
    src_store_OB_bin = format(int(slot[1]), '02b')
    src_store_MEM_bin = format(int(slot[2]), '02b')

    slot7_binary = en_store_bin + src_store_OB_bin + src_store_MEM_bin
    return slot7_binary

def compile_slot0(slot):
    if(slot[0] == 'end'):
        return "1"
    else: return "0"


# def decimal_to_binary_64bit(value):
#     """
#     Chuyển đổi một số nguyên từ decimal sang binary 64 bit.
#
#     Args:
#         value (int): Số nguyên đầu vào.
#
#     Returns:
#         str: Chuỗi nhị phân 64 bit.
#     """
#
#     # print(value[0])
#     if not isinstance(value, int):
#         raise ValueError("Giá trị đầu vào phải là một số nguyên.")
#
#     # Chuyển sang nhị phân, bỏ tiền tố "0b"
#     binary = bin(value & (2 ** 64 - 1))[2:]
#
#     # Thêm các số 0 phía trước để đạt 64 bit
#     binary_64bit = binary.zfill(64)
#
#     return binary_64bit

# def decimal_to_binary_64bit(value):
#     """
#     Chuyển đổi một số từ decimal hoặc hexadecimal sang binary 64 bit.
#
#     Args:
#         value (list): Danh sách chứa một chuỗi số decimal hoặc hexadecimal.
#
#     Returns:
#         str: Chuỗi nhị phân 64 bit.
#     """
#     if not isinstance(value, list) or len(value) != 1:
#         raise ValueError("Đầu vào phải là danh sách chứa đúng một chuỗi số.")
#
#     # Lấy phần tử duy nhất từ danh sách
#     value_str = value[0]
#
#     if value_str.startswith("0x") or value_str.startswith("0X"):
#         # Hexadecimal
#         number = int(value_str, 16)
#     elif value_str.isdigit():
#         # Decimal
#         number = int(value_str)
#     else:
#         raise ValueError("Giá trị đầu vào phải là số decimal hoặc hexadecimal hợp lệ.")
#
#     # Chuyển sang nhị phân, bỏ tiền tố "0b"
#     binary = bin(number & (2 ** 64 - 1))[2:]
#
#     # Thêm các số 0 phía trước để đạt 64 bit
#     binary_64bit = binary.zfill(64)
#
#     return binary_64bit

def decimal_to_binary_64bit(value):
    """
    Chuyển đổi một số từ decimal, hexadecimal hoặc binary sang binary 64 bit.

    Args:
        value (list): Danh sách chứa một chuỗi số decimal, hexadecimal hoặc binary.

    Returns:
        str: Chuỗi nhị phân 64 bit.
    """
    if not isinstance(value, list) or len(value) != 1:
        raise ValueError("\u0110\u1ea7u v\u00e0o ph\u1ea3i l\u00e0 danh s\u00e1ch ch\u1ee9a \u0111\u00fang m\u1ed9t chu\u1ed7i s\u1ed1.")

    # Lấy phần tử duy nhất từ danh sách
    value_str = value[0]

    if value_str.startswith("0b") or value_str.startswith("0B"):
        # Binary
        number = int(value_str, 2)
    elif value_str.startswith("0x") or value_str.startswith("0X"):
        # Hexadecimal
        number = int(value_str, 16)
    elif value_str.isdigit():
        # Decimal
        number = int(value_str)
    else:
        raise ValueError("ERROR")

    # Chuyển sang nhị phân, bỏ tiền tố "0b"
    binary = bin(number & (2 ** 64 - 1))[2:]

    # Thêm các số 0 phía trước để đạt 64 bit
    binary_64bit = binary.zfill(64)
    # print(binary_64bit)
    return binary_64bit


# instructions = ['run 0|add 1 0 0 0 0 0 0 0 0|mld2 0|2 1 0 0|0 0|1 0 0|mst7 1 0',
#                 'run 0|add 3 0 0 0 0 0 0 0 0|mld2 0|2 1 3 0|0 0|1 0 0|mst7 1 0']
                # 'sbp 2|add 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0',
                # 'sof 15|add 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0',
                # 'sit 10|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0',
                # 'run 0|nadd 0 0 0 0 0 0 0 0 0|mld2 0|2 1 0 0',
                # 'run 0|add 0 0 0 0 0 0 0 0 0|mld3 2|2 1 3 0',]

instructions = {
# CONV0
# Phase 1
# xử lý hàng pad - 0 - 1 với 6 filter
    # xử lý hàng pad 0
    0: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",
    # xử lý hàng 0
    #loop
    1: 'nend|sbp 3|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    2: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    3: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    4: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|2 1 3 0|0 0|0 0 0|mst0 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    5: 'nend|run 0|add 96 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    6: 'nend|run 0|add 192 2 1 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',      #1 -> 31
    7: 'nend|run 0|add 0 0 33 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',      #32
    8: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',     # reset thanh ghi chốt
    9: 'nend|run 0|add 0 0 3 2 0 0 0 0 0|mld4 0|0 0 1 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    10: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    11: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop

    # Xử lý hàng 1
    12: 'nend|sbp 8|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    13: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    14: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    15: 'nend|run 0|add 32 0 0 3 0 0 0 0 0|mld4 0|2 1 1 0|0 0|0 0 0|mst0 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    16: 'nend|run 0|add 128 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    17: 'nend|run 0|add 224 2 4 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    18: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    19: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    20: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    21: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    22: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    23: 'nend|run 0|add 0 0 36 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    24: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt

    # Đưa các output trong OSP 9, 19, 29, 39, 49, 59 từ địa chỉ 5 đến 36 qua LUT
    # Đọc OSP 9
    25: 'nend|run 0|add 0 0 0 5 0 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    26: 'nend|run 0|add 0 0 0 6 0 0 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    27: 'nend|run 0|add 0 0 0 7 1 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    28: 'nend|run 0|add 0 0 0 8 1 1 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    29: 'nend|run 0|add 0 0 0 9 2 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    30: 'nend|run 0|add 0 0 0 10 2 2 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    31: 'nend|run 0|add 0 0 0 11 3 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    32: 'nend|run 0|add 0 0 0 12 3 3 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    33: 'nend|run 0|add 0 0 0 13 4 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    34: 'nend|run 0|add 0 0 0 14 4 4 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    35: 'nend|run 0|add 0 0 0 15 5 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    36: 'nend|run 0|add 0 0 0 16 5 5 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    37: 'nend|run 0|add 0 0 0 17 6 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    38: 'nend|run 0|add 0 0 0 18 6 6 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    39: 'nend|run 0|add 0 0 0 19 7 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    40: 'nend|run 0|add 0 0 0 20 7 7 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    41: 'nend|run 0|add 0 0 0 21 8 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    42: 'nend|run 0|add 0 0 0 22 8 8 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    43: 'nend|run 0|add 0 0 0 23 9 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    44: 'nend|run 0|add 0 0 0 24 9 9 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    45: 'nend|run 0|add 0 0 0 25 10 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    46: 'nend|run 0|add 0 0 0 26 10 10 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    47: 'nend|run 0|add 0 0 0 27 11 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    48: 'nend|run 0|add 0 0 0 28 11 11 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    49: 'nend|run 0|add 0 0 0 29 12 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    50: 'nend|run 0|add 0 0 0 30 12 12 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    51: 'nend|run 0|add 0 0 0 31 13 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    52: 'nend|run 0|add 0 0 0 32 13 13 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    53: 'nend|run 0|add 0 0 0 33 14 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    54: 'nend|run 0|add 0 0 0 34 14 14 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    55: 'nend|run 0|add 0 0 0 35 15 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    56: 'nend|run 0|add 0 0 0 36 15 15 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',

    # Đọc OSP 19
    57: 'nend|run 0|add 0 0 0 5 16 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    58: 'nend|run 0|add 0 0 0 6 16 16 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    59: 'nend|run 0|add 0 0 0 7 17 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    60: 'nend|run 0|add 0 0 0 8 17 17 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    61: 'nend|run 0|add 0 0 0 9 18 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    62: 'nend|run 0|add 0 0 0 10 18 18 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    63: 'nend|run 0|add 0 0 0 11 19 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    64: 'nend|run 0|add 0 0 0 12 19 19 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    65: 'nend|run 0|add 0 0 0 13 20 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    66: 'nend|run 0|add 0 0 0 14 20 20 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    67: 'nend|run 0|add 0 0 0 15 21 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    68: 'nend|run 0|add 0 0 0 16 21 21 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    69: 'nend|run 0|add 0 0 0 17 22 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    70: 'nend|run 0|add 0 0 0 18 22 22 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    71: 'nend|run 0|add 0 0 0 19 23 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    72: 'nend|run 0|add 0 0 0 20 23 23 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    73: 'nend|run 0|add 0 0 0 21 24 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    74: 'nend|run 0|add 0 0 0 22 24 24 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    75: 'nend|run 0|add 0 0 0 23 25 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    76: 'nend|run 0|add 0 0 0 24 25 25 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    77: 'nend|run 0|add 0 0 0 25 26 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    78: 'nend|run 0|add 0 0 0 26 26 26 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    79: 'nend|run 0|add 0 0 0 27 27 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    80: 'nend|run 0|add 0 0 0 28 27 27 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    81: 'nend|run 0|add 0 0 0 29 28 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    82: 'nend|run 0|add 0 0 0 30 28 28 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    83: 'nend|run 0|add 0 0 0 31 29 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    84: 'nend|run 0|add 0 0 0 32 29 29 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    85: 'nend|run 0|add 0 0 0 33 30 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    86: 'nend|run 0|add 0 0 0 34 30 30 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    87: 'nend|run 0|add 0 0 0 35 31 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    88: 'nend|run 0|add 0 0 0 36 31 31 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',


    # Đọc OSP 29
    89: 'nend|run 0|add 0 0 0 5 32 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    90: 'nend|run 0|add 0 0 0 6 32 32 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    91: 'nend|run 0|add 0 0 0 7 33 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    92: 'nend|run 0|add 0 0 0 8 33 33 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    93: 'nend|run 0|add 0 0 0 9 34 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    94: 'nend|run 0|add 0 0 0 10 34 34 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    95: 'nend|run 0|add 0 0 0 11 35 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    96: 'nend|run 0|add 0 0 0 12 35 35 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    97: 'nend|run 0|add 0 0 0 13 36 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    98: 'nend|run 0|add 0 0 0 14 36 36 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    99: 'nend|run 0|add 0 0 0 15 37 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    100: 'nend|run 0|add 0 0 0 16 37 37 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    101: 'nend|run 0|add 0 0 0 17 38 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    102: 'nend|run 0|add 0 0 0 18 38 38 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    103: 'nend|run 0|add 0 0 0 19 39 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    104: 'nend|run 0|add 0 0 0 20 39 39 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    105: 'nend|run 0|add 0 0 0 21 40 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    106: 'nend|run 0|add 0 0 0 22 40 40 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    107: 'nend|run 0|add 0 0 0 23 41 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    108: 'nend|run 0|add 0 0 0 24 41 41 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    109: 'nend|run 0|add 0 0 0 25 42 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    110: 'nend|run 0|add 0 0 0 26 42 42 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    111: 'nend|run 0|add 0 0 0 27 43 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    112: 'nend|run 0|add 0 0 0 28 43 43 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    113: 'nend|run 0|add 0 0 0 29 44 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    114: 'nend|run 0|add 0 0 0 30 44 44 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    115: 'nend|run 0|add 0 0 0 31 45 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    116: 'nend|run 0|add 0 0 0 32 45 45 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    117: 'nend|run 0|add 0 0 0 33 46 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    118: 'nend|run 0|add 0 0 0 34 46 46 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    119: 'nend|run 0|add 0 0 0 35 47 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    120: 'nend|run 0|add 0 0 0 36 47 47 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',

    # Đọc OSP 39
    121: 'nend|run 0|add 0 0 0 5 48 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    122: 'nend|run 0|add 0 0 0 6 48 48 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    123: 'nend|run 0|add 0 0 0 7 49 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    124: 'nend|run 0|add 0 0 0 8 49 49 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    125: 'nend|run 0|add 0 0 0 9 50 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    126: 'nend|run 0|add 0 0 0 10 50 50 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    127: 'nend|run 0|add 0 0 0 11 51 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    128: 'nend|run 0|add 0 0 0 12 51 51 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    129: 'nend|run 0|add 0 0 0 13 52 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    130: 'nend|run 0|add 0 0 0 14 52 52 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    131: 'nend|run 0|add 0 0 0 15 53 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    132: 'nend|run 0|add 0 0 0 16 53 53 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    133: 'nend|run 0|add 0 0 0 17 54 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    134: 'nend|run 0|add 0 0 0 18 54 54 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    135: 'nend|run 0|add 0 0 0 19 55 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    136: 'nend|run 0|add 0 0 0 20 55 55 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    137: 'nend|run 0|add 0 0 0 21 56 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    138: 'nend|run 0|add 0 0 0 22 56 56 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    139: 'nend|run 0|add 0 0 0 23 57 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    140: 'nend|run 0|add 0 0 0 24 57 57 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    141: 'nend|run 0|add 0 0 0 25 58 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    142: 'nend|run 0|add 0 0 0 26 58 58 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    143: 'nend|run 0|add 0 0 0 27 59 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    144: 'nend|run 0|add 0 0 0 28 59 59 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    145: 'nend|run 0|add 0 0 0 29 60 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    146: 'nend|run 0|add 0 0 0 30 60 60 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    147: 'nend|run 0|add 0 0 0 31 61 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    148: 'nend|run 0|add 0 0 0 32 61 61 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    149: 'nend|run 0|add 0 0 0 33 62 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    150: 'nend|run 0|add 0 0 0 34 62 62 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    151: 'nend|run 0|add 0 0 0 35 63 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    152: 'nend|run 0|add 0 0 0 36 63 63 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',

    # Đọc OSP 49
    153: 'nend|run 0|add 0 0 0 5 64 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    154: 'nend|run 0|add 0 0 0 6 64 64 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    155: 'nend|run 0|add 0 0 0 7 65 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    156: 'nend|run 0|add 0 0 0 8 65 65 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    157: 'nend|run 0|add 0 0 0 9 66 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    158: 'nend|run 0|add 0 0 0 10 66 66 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    159: 'nend|run 0|add 0 0 0 11 67 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    160: 'nend|run 0|add 0 0 0 12 67 67 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    161: 'nend|run 0|add 0 0 0 13 68 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    162: 'nend|run 0|add 0 0 0 14 68 68 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    163: 'nend|run 0|add 0 0 0 15 69 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    164: 'nend|run 0|add 0 0 0 16 69 69 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    165: 'nend|run 0|add 0 0 0 17 70 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    166: 'nend|run 0|add 0 0 0 18 70 70 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    167: 'nend|run 0|add 0 0 0 19 71 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    168: 'nend|run 0|add 0 0 0 20 71 71 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    169: 'nend|run 0|add 0 0 0 21 72 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    170: 'nend|run 0|add 0 0 0 22 72 72 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    171: 'nend|run 0|add 0 0 0 23 73 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    172: 'nend|run 0|add 0 0 0 24 73 73 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    173: 'nend|run 0|add 0 0 0 25 74 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    174: 'nend|run 0|add 0 0 0 26 74 74 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    175: 'nend|run 0|add 0 0 0 27 75 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    176: 'nend|run 0|add 0 0 0 28 75 75 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    177: 'nend|run 0|add 0 0 0 29 76 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    178: 'nend|run 0|add 0 0 0 30 76 76 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    179: 'nend|run 0|add 0 0 0 31 77 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    180: 'nend|run 0|add 0 0 0 32 77 77 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    181: 'nend|run 0|add 0 0 0 33 78 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    182: 'nend|run 0|add 0 0 0 34 78 78 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    183: 'nend|run 0|add 0 0 0 35 79 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    184: 'nend|run 0|add 0 0 0 36 79 79 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',

    # Đọc OSP 59
    185: 'nend|run 0|add 0 0 0 5 80 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    186: 'nend|run 0|add 0 0 0 6 80 80 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    187: 'nend|run 0|add 0 0 0 7 81 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    188: 'nend|run 0|add 0 0 0 8 81 81 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    189: 'nend|run 0|add 0 0 0 9 82 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    190: 'nend|run 0|add 0 0 0 10 82 82 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    191: 'nend|run 0|add 0 0 0 11 83 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    192: 'nend|run 0|add 0 0 0 12 83 83 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    193: 'nend|run 0|add 0 0 0 13 84 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    194: 'nend|run 0|add 0 0 0 14 84 84 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    195: 'nend|run 0|add 0 0 0 15 85 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    196: 'nend|run 0|add 0 0 0 16 85 85 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    197: 'nend|run 0|add 0 0 0 17 86 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    198: 'nend|run 0|add 0 0 0 18 86 86 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    199: 'nend|run 0|add 0 0 0 19 87 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    200: 'nend|run 0|add 0 0 0 20 87 87 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    201: 'nend|run 0|add 0 0 0 21 88 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    202: 'nend|run 0|add 0 0 0 22 88 88 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    203: 'nend|run 0|add 0 0 0 23 89 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    204: 'nend|run 0|add 0 0 0 24 89 89 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    205: 'nend|run 0|add 0 0 0 25 90 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    206: 'nend|run 0|add 0 0 0 26 90 90 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    207: 'nend|run 0|add 0 0 0 27 91 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    208: 'nend|run 0|add 0 0 0 28 91 91 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    209: 'nend|run 0|add 0 0 0 29 92 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    210: 'nend|run 0|add 0 0 0 30 92 92 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    211: 'nend|run 0|add 0 0 0 31 93 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    212: 'nend|run 0|add 0 0 0 32 93 93 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    213: 'nend|run 0|add 0 0 0 33 94 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    214: 'nend|run 0|add 0 0 0 34 94 94 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    215: 'nend|run 0|add 0 0 0 35 95 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    216: 'nend|run 0|add 0 0 0 36 95 95 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',

    217: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop


# xử lý hàng 0 - 1 - 2 với filter 6 filter đầu tiên
    # Xử lý hàng 0
    218: 'nend|sbp 3|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    219: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    220: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    221: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|2 1 3 0|0 0|0 0 0|mst0 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',
    222: 'nend|run 0|add 96 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',
    223: 'nend|run 0|add 192 2 1 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',      #1 -> 31
    224: 'nend|run 0|add 0 0 33 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',      #32
    225: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',     # reset thanh ghi chốt
    226: 'nend|run 0|add 0 0 3 2 0 0 0 0 0|mld4 0|0 0 1 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',        # đưa giá trị đầu trong 32 giá trị sang mem tiếp theo (để bỏ qua tính toán padding)
    227: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    228: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop

    # Xử lý hàng 1
    229: 'nend|sbp 8|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    230: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    231: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',       # loop cho 31 output đầu
    232: 'nend|run 0|add 32 0 0 3 0 0 0 0 0|mld4 0|2 1 1 0|0 0|0 0 0|mst0 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    233: 'nend|run 0|add 128 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    234: 'nend|run 0|add 224 2 4 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    235: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    236: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    237: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    238: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    239: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    240: 'nend|run 0|add 0 0 36 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',   # output thứ 32
    241: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt
    242: 'nend|run 0|add 0 0 6 5 0 0 0 0 0|mld4 0|0 0 1 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',    # đưa giá trị đầu trong 32 giá trị sang mem tiếp theo (để bỏ qua tính toán padding)
    243: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    244: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    # Xử lý hàng 2
    245: 'nend|sbp 8|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    246: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    247: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',       # Xử lý output từ 1 -> 31
    248: 'nend|run 0|add 64 0 0 6 0 0 0 0 0|mld4 0|2 1 1 0|0 0|0 0 0|mst0 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    249: 'nend|run 0|add 160 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    250: 'nend|run 0|add 256 2 7 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    251: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    252: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    253: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    254: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    255: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    256: 'nend|run 0|add 0 0 39 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',   #xử lý output 32
    257: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt
    # Đưa các output trong OSP 9, 19, 29, 39, 49, 59 từ địa chỉ 8 đến 39 qua LUT
    # OSP 9
    258: 'nend|run 0|add 0 0 0 8 0 0 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    259: 'nend|run 0|add 0 0 0 9 0 0 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    260: 'nend|run 0|add 0 0 0 10 1 1 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    261: 'nend|run 0|add 0 0 0 11 1 1 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    262: 'nend|run 0|add 0 0 0 12 2 2 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    263: 'nend|run 0|add 0 0 0 13 2 2 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    264: 'nend|run 0|add 0 0 0 14 3 3 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    265: 'nend|run 0|add 0 0 0 15 3 3 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    266: 'nend|run 0|add 0 0 0 16 4 4 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    267: 'nend|run 0|add 0 0 0 17 4 4 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    268: 'nend|run 0|add 0 0 0 18 5 5 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    269: 'nend|run 0|add 0 0 0 19 5 5 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    270: 'nend|run 0|add 0 0 0 20 6 6 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    271: 'nend|run 0|add 0 0 0 21 6 6 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    272: 'nend|run 0|add 0 0 0 22 7 7 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    273: 'nend|run 0|add 0 0 0 23 7 7 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    274: 'nend|run 0|add 0 0 0 24 8 8 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    275: 'nend|run 0|add 0 0 0 25 8 8 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    276: 'nend|run 0|add 0 0 0 26 9 9 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    277: 'nend|run 0|add 0 0 0 27 9 9 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    278: 'nend|run 0|add 0 0 0 28 10 10 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    279: 'nend|run 0|add 0 0 0 29 10 10 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    280: 'nend|run 0|add 0 0 0 30 11 11 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    281: 'nend|run 0|add 0 0 0 31 11 11 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    282: 'nend|run 0|add 0 0 0 32 12 12 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    283: 'nend|run 0|add 0 0 0 33 12 12 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    284: 'nend|run 0|add 0 0 0 34 13 13 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    285: 'nend|run 0|add 0 0 0 35 13 13 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    286: 'nend|run 0|add 0 0 0 36 14 14 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    287: 'nend|run 0|add 0 0 0 37 14 14 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    288: 'nend|run 0|add 0 0 0 38 15 15 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    289: 'nend|run 0|add 0 0 0 39 15 15 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # OSP 19
    290: 'nend|run 0|add 0 0 0 8 16 16 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    291: 'nend|run 0|add 0 0 0 9 16 16 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    292: 'nend|run 0|add 0 0 0 10 17 17 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    293: 'nend|run 0|add 0 0 0 11 17 17 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    294: 'nend|run 0|add 0 0 0 12 18 18 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    295: 'nend|run 0|add 0 0 0 13 18 18 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    296: 'nend|run 0|add 0 0 0 14 19 19 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    297: 'nend|run 0|add 0 0 0 15 19 19 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    298: 'nend|run 0|add 0 0 0 16 20 20 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    299: 'nend|run 0|add 0 0 0 17 20 20 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    300: 'nend|run 0|add 0 0 0 18 21 21 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    301: 'nend|run 0|add 0 0 0 19 21 21 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    302: 'nend|run 0|add 0 0 0 20 22 22 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    303: 'nend|run 0|add 0 0 0 21 22 22 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    304: 'nend|run 0|add 0 0 0 22 23 23 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    305: 'nend|run 0|add 0 0 0 23 23 23 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    306: 'nend|run 0|add 0 0 0 24 24 24 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    307: 'nend|run 0|add 0 0 0 25 24 24 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    308: 'nend|run 0|add 0 0 0 26 25 25 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    309: 'nend|run 0|add 0 0 0 27 25 25 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    310: 'nend|run 0|add 0 0 0 28 26 26 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    311: 'nend|run 0|add 0 0 0 29 26 26 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    312: 'nend|run 0|add 0 0 0 30 27 27 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    313: 'nend|run 0|add 0 0 0 31 27 27 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    314: 'nend|run 0|add 0 0 0 32 28 28 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    315: 'nend|run 0|add 0 0 0 33 28 28 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    316: 'nend|run 0|add 0 0 0 34 29 29 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    317: 'nend|run 0|add 0 0 0 35 29 29 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    318: 'nend|run 0|add 0 0 0 36 30 30 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    319: 'nend|run 0|add 0 0 0 37 30 30 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    320: 'nend|run 0|add 0 0 0 38 31 31 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    321: 'nend|run 0|add 0 0 0 39 31 31 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 29
    322: 'nend|run 0|add 0 0 0 8 32 32 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    323: 'nend|run 0|add 0 0 0 9 32 32 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    324: 'nend|run 0|add 0 0 0 10 33 33 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    325: 'nend|run 0|add 0 0 0 11 33 33 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    326: 'nend|run 0|add 0 0 0 12 34 34 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    327: 'nend|run 0|add 0 0 0 13 34 34 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    328: 'nend|run 0|add 0 0 0 14 35 35 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    329: 'nend|run 0|add 0 0 0 15 35 35 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    330: 'nend|run 0|add 0 0 0 16 36 36 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    331: 'nend|run 0|add 0 0 0 17 36 36 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    332: 'nend|run 0|add 0 0 0 18 37 37 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    333: 'nend|run 0|add 0 0 0 19 37 37 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    334: 'nend|run 0|add 0 0 0 20 38 38 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    335: 'nend|run 0|add 0 0 0 21 38 38 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    336: 'nend|run 0|add 0 0 0 22 39 39 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    337: 'nend|run 0|add 0 0 0 23 39 39 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    338: 'nend|run 0|add 0 0 0 24 40 40 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    339: 'nend|run 0|add 0 0 0 25 40 40 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    340: 'nend|run 0|add 0 0 0 26 41 41 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    341: 'nend|run 0|add 0 0 0 27 41 41 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    342: 'nend|run 0|add 0 0 0 28 42 42 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    343: 'nend|run 0|add 0 0 0 29 42 42 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    344: 'nend|run 0|add 0 0 0 30 43 43 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    345: 'nend|run 0|add 0 0 0 31 43 43 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    346: 'nend|run 0|add 0 0 0 32 44 44 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    347: 'nend|run 0|add 0 0 0 33 44 44 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    348: 'nend|run 0|add 0 0 0 34 45 45 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    349: 'nend|run 0|add 0 0 0 35 45 45 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    350: 'nend|run 0|add 0 0 0 36 46 46 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    351: 'nend|run 0|add 0 0 0 37 46 46 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    352: 'nend|run 0|add 0 0 0 38 47 47 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    353: 'nend|run 0|add 0 0 0 39 47 47 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 39
    354: 'nend|run 0|add 0 0 0 8 48 48 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    355: 'nend|run 0|add 0 0 0 9 48 48 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    356: 'nend|run 0|add 0 0 0 10 49 49 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    357: 'nend|run 0|add 0 0 0 11 49 49 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    358: 'nend|run 0|add 0 0 0 12 50 50 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    359: 'nend|run 0|add 0 0 0 13 50 50 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    360: 'nend|run 0|add 0 0 0 14 51 51 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    361: 'nend|run 0|add 0 0 0 15 51 51 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    362: 'nend|run 0|add 0 0 0 16 52 52 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    363: 'nend|run 0|add 0 0 0 17 52 52 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    364: 'nend|run 0|add 0 0 0 18 53 53 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    365: 'nend|run 0|add 0 0 0 19 53 53 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    366: 'nend|run 0|add 0 0 0 20 54 54 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    367: 'nend|run 0|add 0 0 0 21 54 54 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    368: 'nend|run 0|add 0 0 0 22 55 55 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    369: 'nend|run 0|add 0 0 0 23 55 55 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    370: 'nend|run 0|add 0 0 0 24 56 56 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    371: 'nend|run 0|add 0 0 0 25 56 56 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    372: 'nend|run 0|add 0 0 0 26 57 57 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    373: 'nend|run 0|add 0 0 0 27 57 57 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    374: 'nend|run 0|add 0 0 0 28 58 58 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    375: 'nend|run 0|add 0 0 0 29 58 58 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    376: 'nend|run 0|add 0 0 0 30 59 59 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    377: 'nend|run 0|add 0 0 0 31 59 59 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    378: 'nend|run 0|add 0 0 0 32 60 60 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    379: 'nend|run 0|add 0 0 0 33 60 60 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    380: 'nend|run 0|add 0 0 0 34 61 61 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    381: 'nend|run 0|add 0 0 0 35 61 61 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    382: 'nend|run 0|add 0 0 0 36 62 62 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    383: 'nend|run 0|add 0 0 0 37 62 62 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    384: 'nend|run 0|add 0 0 0 38 63 63 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    385: 'nend|run 0|add 0 0 0 39 63 63 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 49
    386: 'nend|run 0|add 0 0 0 8 64 64 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    387: 'nend|run 0|add 0 0 0 9 64 64 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    388: 'nend|run 0|add 0 0 0 10 65 65 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    389: 'nend|run 0|add 0 0 0 11 65 65 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    390: 'nend|run 0|add 0 0 0 12 66 66 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    391: 'nend|run 0|add 0 0 0 13 66 66 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    392: 'nend|run 0|add 0 0 0 14 67 67 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    393: 'nend|run 0|add 0 0 0 15 67 67 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    394: 'nend|run 0|add 0 0 0 16 68 68 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    395: 'nend|run 0|add 0 0 0 17 68 68 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    396: 'nend|run 0|add 0 0 0 18 69 69 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    397: 'nend|run 0|add 0 0 0 19 69 69 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    398: 'nend|run 0|add 0 0 0 20 70 70 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    399: 'nend|run 0|add 0 0 0 21 70 70 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    400: 'nend|run 0|add 0 0 0 22 71 71 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    401: 'nend|run 0|add 0 0 0 23 71 71 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    402: 'nend|run 0|add 0 0 0 24 72 72 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    403: 'nend|run 0|add 0 0 0 25 72 72 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    404: 'nend|run 0|add 0 0 0 26 73 73 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    405: 'nend|run 0|add 0 0 0 27 73 73 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    406: 'nend|run 0|add 0 0 0 28 74 74 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    407: 'nend|run 0|add 0 0 0 29 74 74 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    408: 'nend|run 0|add 0 0 0 30 75 75 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    409: 'nend|run 0|add 0 0 0 31 75 75 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    410: 'nend|run 0|add 0 0 0 32 76 76 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    411: 'nend|run 0|add 0 0 0 33 76 76 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    412: 'nend|run 0|add 0 0 0 34 77 77 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    413: 'nend|run 0|add 0 0 0 35 77 77 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    414: 'nend|run 0|add 0 0 0 36 78 78 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    415: 'nend|run 0|add 0 0 0 37 78 78 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    416: 'nend|run 0|add 0 0 0 38 79 79 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    417: 'nend|run 0|add 0 0 0 39 79 79 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 59
    418: 'nend|run 0|add 0 0 0 8 80 80 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    419: 'nend|run 0|add 0 0 0 9 80 80 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    420: 'nend|run 0|add 0 0 0 10 81 81 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    421: 'nend|run 0|add 0 0 0 11 81 81 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    422: 'nend|run 0|add 0 0 0 12 82 82 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    423: 'nend|run 0|add 0 0 0 13 82 82 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    424: 'nend|run 0|add 0 0 0 14 83 83 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    425: 'nend|run 0|add 0 0 0 15 83 83 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    426: 'nend|run 0|add 0 0 0 16 84 84 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    427: 'nend|run 0|add 0 0 0 17 84 84 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    428: 'nend|run 0|add 0 0 0 18 85 85 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    429: 'nend|run 0|add 0 0 0 19 85 85 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    430: 'nend|run 0|add 0 0 0 20 86 86 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    431: 'nend|run 0|add 0 0 0 21 86 86 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    432: 'nend|run 0|add 0 0 0 22 87 87 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    433: 'nend|run 0|add 0 0 0 23 87 87 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    434: 'nend|run 0|add 0 0 0 24 88 88 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    435: 'nend|run 0|add 0 0 0 25 88 88 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    436: 'nend|run 0|add 0 0 0 26 89 89 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    437: 'nend|run 0|add 0 0 0 27 89 89 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    438: 'nend|run 0|add 0 0 0 28 90 90 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    439: 'nend|run 0|add 0 0 0 29 90 90 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    440: 'nend|run 0|add 0 0 0 30 91 91 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    441: 'nend|run 0|add 0 0 0 31 91 91 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    442: 'nend|run 0|add 0 0 0 32 92 92 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    443: 'nend|run 0|add 0 0 0 33 92 92 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    444: 'nend|run 0|add 0 0 0 34 93 93 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    445: 'nend|run 0|add 0 0 0 35 93 93 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    446: 'nend|run 0|add 0 0 0 36 94 94 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    447: 'nend|run 0|add 0 0 0 37 94 94 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    448: 'nend|run 0|add 0 0 0 38 95 95 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    449: 'nend|run 0|add 0 0 0 39 95 95 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',

    450: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt
    451: "end|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
# End Phase 1


# Phase 2 ================================================
# Xử lý 4 hàng
# xử lý hàng 1 - 2 - 3 với filter 6 filter đầu tiên
    # Xử lý hàng 1
    452: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    453: 'nend|sbp 3|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    454: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    455: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    456: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|2 1 3 0|0 0|0 0 0|mst0 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',
    457: 'nend|run 0|add 128 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',
    458: 'nend|run 0|add 256 2 1 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',      #1 -> 31
    459: 'nend|run 0|add 0 0 33 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',      #32
    460: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',     # reset thanh ghi chốt
    461: 'nend|run 0|add 0 0 3 2 0 0 0 0 0|mld4 0|0 0 1 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',        # đưa giá trị đầu trong 32 giá trị sang mem tiếp theo (để bỏ qua tính toán padding)
    462: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    463: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    # Xử lý hàng 2
    464: 'nend|sbp 8|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    465: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    466: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',       # loop cho 31 output đầu
    467: 'nend|run 0|add 32 0 0 3 0 0 0 0 0|mld4 0|2 1 1 0|0 0|0 0 0|mst0 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    468: 'nend|run 0|add 160 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    469: 'nend|run 0|add 288 2 4 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    470: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    471: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    472: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    473: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    474: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    475: 'nend|run 0|add 0 0 36 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',   # output thứ 32
    476: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt
    477: 'nend|run 0|add 0 0 6 5 0 0 0 0 0|mld4 0|0 0 1 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',    # đưa giá trị đầu trong 32 giá trị sang mem tiếp theo (để bỏ qua tính toán padding)
    478: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    479: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    # Xử lý hàng 3
    480: 'nend|sbp 8|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    481: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    482: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',       # Xử lý output từ 1 -> 31
    483: 'nend|run 0|add 64 0 0 6 0 0 0 0 0|mld4 0|2 1 1 0|0 0|0 0 0|mst0 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    484: 'nend|run 0|add 192 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    485: 'nend|run 0|add 320 2 7 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    486: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    487: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    488: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    489: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    490: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    491: 'nend|run 0|add 0 0 39 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',   #xử lý output 32
    492: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt

# Đưa các output trong OSP 9, 19, 29, 39, 49, 59 từ địa chỉ 8 đến 39 qua LUT
    # Đọc OSP 9
    493: 'nend|run 0|add 0 0 0 8 0 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    494: 'nend|run 0|add 0 0 0 9 0 0 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    495: 'nend|run 0|add 0 0 0 10 1 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    496: 'nend|run 0|add 0 0 0 11 1 1 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    497: 'nend|run 0|add 0 0 0 12 2 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    498: 'nend|run 0|add 0 0 0 13 2 2 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    499: 'nend|run 0|add 0 0 0 14 3 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    500: 'nend|run 0|add 0 0 0 15 3 3 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    501: 'nend|run 0|add 0 0 0 16 4 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    502: 'nend|run 0|add 0 0 0 17 4 4 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    503: 'nend|run 0|add 0 0 0 18 5 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    504: 'nend|run 0|add 0 0 0 19 5 5 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    505: 'nend|run 0|add 0 0 0 20 6 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    506: 'nend|run 0|add 0 0 0 21 6 6 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    507: 'nend|run 0|add 0 0 0 22 7 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    508: 'nend|run 0|add 0 0 0 23 7 7 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    509: 'nend|run 0|add 0 0 0 24 8 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    510: 'nend|run 0|add 0 0 0 25 8 8 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    511: 'nend|run 0|add 0 0 0 26 9 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    512: 'nend|run 0|add 0 0 0 27 9 9 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    513: 'nend|run 0|add 0 0 0 28 10 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    514: 'nend|run 0|add 0 0 0 29 10 10 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    515: 'nend|run 0|add 0 0 0 30 11 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    516: 'nend|run 0|add 0 0 0 31 11 11 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    517: 'nend|run 0|add 0 0 0 32 12 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    518: 'nend|run 0|add 0 0 0 33 12 12 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    519: 'nend|run 0|add 0 0 0 34 13 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    520: 'nend|run 0|add 0 0 0 35 13 13 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    521: 'nend|run 0|add 0 0 0 36 14 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    522: 'nend|run 0|add 0 0 0 37 14 14 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    523: 'nend|run 0|add 0 0 0 38 15 0 0 0 0|mld5 9|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    524: 'nend|run 0|add 0 0 0 39 15 15 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 19
    525: 'nend|run 0|add 0 0 0 8 16 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    526: 'nend|run 0|add 0 0 0 9 16 16 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    527: 'nend|run 0|add 0 0 0 10 17 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    528: 'nend|run 0|add 0 0 0 11 17 17 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    529: 'nend|run 0|add 0 0 0 12 18 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    530: 'nend|run 0|add 0 0 0 13 18 18 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    531: 'nend|run 0|add 0 0 0 14 19 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    532: 'nend|run 0|add 0 0 0 15 19 19 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    533: 'nend|run 0|add 0 0 0 16 20 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    534: 'nend|run 0|add 0 0 0 17 20 20 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    535: 'nend|run 0|add 0 0 0 18 21 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    536: 'nend|run 0|add 0 0 0 19 21 21 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    537: 'nend|run 0|add 0 0 0 20 22 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    538: 'nend|run 0|add 0 0 0 21 22 22 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    539: 'nend|run 0|add 0 0 0 22 23 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    540: 'nend|run 0|add 0 0 0 23 23 23 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    541: 'nend|run 0|add 0 0 0 24 24 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    542: 'nend|run 0|add 0 0 0 25 24 24 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    543: 'nend|run 0|add 0 0 0 26 25 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    544: 'nend|run 0|add 0 0 0 27 25 25 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    545: 'nend|run 0|add 0 0 0 28 26 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    546: 'nend|run 0|add 0 0 0 29 26 26 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    547: 'nend|run 0|add 0 0 0 30 27 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    548: 'nend|run 0|add 0 0 0 31 27 27 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    549: 'nend|run 0|add 0 0 0 32 28 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    550: 'nend|run 0|add 0 0 0 33 28 28 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    551: 'nend|run 0|add 0 0 0 34 29 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    552: 'nend|run 0|add 0 0 0 35 29 29 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    553: 'nend|run 0|add 0 0 0 36 30 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    554: 'nend|run 0|add 0 0 0 37 30 30 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    555: 'nend|run 0|add 0 0 0 38 31 0 1 0 0|mld5 19|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    556: 'nend|run 0|add 0 0 0 39 31 31 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 29
    557: 'nend|run 0|add 0 0 0 8 32 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    558: 'nend|run 0|add 0 0 0 9 32 32 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    559: 'nend|run 0|add 0 0 0 10 33 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    560: 'nend|run 0|add 0 0 0 11 33 33 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    561: 'nend|run 0|add 0 0 0 12 34 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    562: 'nend|run 0|add 0 0 0 13 34 34 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    563: 'nend|run 0|add 0 0 0 14 35 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    564: 'nend|run 0|add 0 0 0 15 35 35 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    565: 'nend|run 0|add 0 0 0 16 36 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    566: 'nend|run 0|add 0 0 0 17 36 36 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    567: 'nend|run 0|add 0 0 0 18 37 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    568: 'nend|run 0|add 0 0 0 19 37 37 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    569: 'nend|run 0|add 0 0 0 20 38 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    570: 'nend|run 0|add 0 0 0 21 38 38 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    571: 'nend|run 0|add 0 0 0 22 39 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    572: 'nend|run 0|add 0 0 0 23 39 39 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    573: 'nend|run 0|add 0 0 0 24 40 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    574: 'nend|run 0|add 0 0 0 25 40 40 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    575: 'nend|run 0|add 0 0 0 26 41 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    576: 'nend|run 0|add 0 0 0 27 41 41 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    577: 'nend|run 0|add 0 0 0 28 42 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    578: 'nend|run 0|add 0 0 0 29 42 42 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    579: 'nend|run 0|add 0 0 0 30 43 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    580: 'nend|run 0|add 0 0 0 31 43 43 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    581: 'nend|run 0|add 0 0 0 32 44 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    582: 'nend|run 0|add 0 0 0 33 44 44 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    583: 'nend|run 0|add 0 0 0 34 45 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    584: 'nend|run 0|add 0 0 0 35 45 45 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    585: 'nend|run 0|add 0 0 0 36 46 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    586: 'nend|run 0|add 0 0 0 37 46 46 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    587: 'nend|run 0|add 0 0 0 38 47 0 2 0 0|mld5 29|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    588: 'nend|run 0|add 0 0 0 39 47 47 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 39
    589: 'nend|run 0|add 0 0 0 8 48 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    590: 'nend|run 0|add 0 0 0 9 48 48 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    591: 'nend|run 0|add 0 0 0 10 49 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    592: 'nend|run 0|add 0 0 0 11 49 49 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    593: 'nend|run 0|add 0 0 0 12 50 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    594: 'nend|run 0|add 0 0 0 13 50 50 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    595: 'nend|run 0|add 0 0 0 14 51 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    596: 'nend|run 0|add 0 0 0 15 51 51 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    597: 'nend|run 0|add 0 0 0 16 52 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    598: 'nend|run 0|add 0 0 0 17 52 52 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    599: 'nend|run 0|add 0 0 0 18 53 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    600: 'nend|run 0|add 0 0 0 19 53 53 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    601: 'nend|run 0|add 0 0 0 20 54 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    602: 'nend|run 0|add 0 0 0 21 54 54 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    603: 'nend|run 0|add 0 0 0 22 55 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    604: 'nend|run 0|add 0 0 0 23 55 55 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    605: 'nend|run 0|add 0 0 0 24 56 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    606: 'nend|run 0|add 0 0 0 25 56 56 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    607: 'nend|run 0|add 0 0 0 26 57 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    608: 'nend|run 0|add 0 0 0 27 57 57 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    609: 'nend|run 0|add 0 0 0 28 58 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    610: 'nend|run 0|add 0 0 0 29 58 58 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    611: 'nend|run 0|add 0 0 0 30 59 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    612: 'nend|run 0|add 0 0 0 31 59 59 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    613: 'nend|run 0|add 0 0 0 32 60 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    614: 'nend|run 0|add 0 0 0 33 60 60 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    615: 'nend|run 0|add 0 0 0 34 61 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    616: 'nend|run 0|add 0 0 0 35 61 61 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    617: 'nend|run 0|add 0 0 0 36 62 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    618: 'nend|run 0|add 0 0 0 37 62 62 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    619: 'nend|run 0|add 0 0 0 38 63 0 3 0 0|mld5 39|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    620: 'nend|run 0|add 0 0 0 39 63 63 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 49
    621: 'nend|run 0|add 0 0 0 8 64 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    622: 'nend|run 0|add 0 0 0 9 64 64 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    623: 'nend|run 0|add 0 0 0 10 65 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    624: 'nend|run 0|add 0 0 0 11 65 65 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    625: 'nend|run 0|add 0 0 0 12 66 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    626: 'nend|run 0|add 0 0 0 13 66 66 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    627: 'nend|run 0|add 0 0 0 14 67 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    628: 'nend|run 0|add 0 0 0 15 67 67 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    629: 'nend|run 0|add 0 0 0 16 68 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    630: 'nend|run 0|add 0 0 0 17 68 68 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    631: 'nend|run 0|add 0 0 0 18 69 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    632: 'nend|run 0|add 0 0 0 19 69 69 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    633: 'nend|run 0|add 0 0 0 20 70 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    634: 'nend|run 0|add 0 0 0 21 70 70 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    635: 'nend|run 0|add 0 0 0 22 71 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    636: 'nend|run 0|add 0 0 0 23 71 71 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    637: 'nend|run 0|add 0 0 0 24 72 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    638: 'nend|run 0|add 0 0 0 25 72 72 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    639: 'nend|run 0|add 0 0 0 26 73 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    640: 'nend|run 0|add 0 0 0 27 73 73 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    641: 'nend|run 0|add 0 0 0 28 74 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    642: 'nend|run 0|add 0 0 0 29 74 74 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    643: 'nend|run 0|add 0 0 0 30 75 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    644: 'nend|run 0|add 0 0 0 31 75 75 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    645: 'nend|run 0|add 0 0 0 32 76 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    646: 'nend|run 0|add 0 0 0 33 76 76 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    647: 'nend|run 0|add 0 0 0 34 77 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    648: 'nend|run 0|add 0 0 0 35 77 77 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    649: 'nend|run 0|add 0 0 0 36 78 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    650: 'nend|run 0|add 0 0 0 37 78 78 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    651: 'nend|run 0|add 0 0 0 38 79 0 4 0 0|mld5 49|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    652: 'nend|run 0|add 0 0 0 39 79 79 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 59
    653: 'nend|run 0|add 0 0 0 8 80 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    654: 'nend|run 0|add 0 0 0 9 80 80 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    655: 'nend|run 0|add 0 0 0 10 81 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    656: 'nend|run 0|add 0 0 0 11 81 81 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    657: 'nend|run 0|add 0 0 0 12 82 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    658: 'nend|run 0|add 0 0 0 13 82 82 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    659: 'nend|run 0|add 0 0 0 14 83 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    660: 'nend|run 0|add 0 0 0 15 83 83 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    661: 'nend|run 0|add 0 0 0 16 84 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    662: 'nend|run 0|add 0 0 0 17 84 84 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    663: 'nend|run 0|add 0 0 0 18 85 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    664: 'nend|run 0|add 0 0 0 19 85 85 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    665: 'nend|run 0|add 0 0 0 20 86 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    666: 'nend|run 0|add 0 0 0 21 86 86 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    667: 'nend|run 0|add 0 0 0 22 87 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    668: 'nend|run 0|add 0 0 0 23 87 87 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    669: 'nend|run 0|add 0 0 0 24 88 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    670: 'nend|run 0|add 0 0 0 25 88 88 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    671: 'nend|run 0|add 0 0 0 26 89 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    672: 'nend|run 0|add 0 0 0 27 89 89 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    673: 'nend|run 0|add 0 0 0 28 90 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    674: 'nend|run 0|add 0 0 0 29 90 90 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    675: 'nend|run 0|add 0 0 0 30 91 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    676: 'nend|run 0|add 0 0 0 31 91 91 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    677: 'nend|run 0|add 0 0 0 32 92 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    678: 'nend|run 0|add 0 0 0 33 92 92 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    679: 'nend|run 0|add 0 0 0 34 93 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    680: 'nend|run 0|add 0 0 0 35 93 93 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    681: 'nend|run 0|add 0 0 0 36 94 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    682: 'nend|run 0|add 0 0 0 37 94 94 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    683: 'nend|run 0|add 0 0 0 38 95 0 5 0 0|mld5 59|0 0 0 0|0 0|0 0 0|mst1 2 0|0',
    684: 'nend|run 0|add 0 0 0 39 95 95 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',

    685: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop



# xử lý hàng 2 - 3 - 4 với 6 filter đầu tiên
    # Xử lý hàng 2
    686: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    687: 'nend|sbp 3|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    688: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    689: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    690: 'nend|run 0|add 32 0 0 0 0 0 0 0 0|mld2 0|2 1 3 0|0 0|0 0 0|mst0 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',
    691: 'nend|run 0|add 160 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',
    692: 'nend|run 0|add 288 2 1 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',      #1 -> 31
    693: 'nend|run 0|add 0 0 33 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',      #32
    694: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',     # reset thanh ghi chốt
    695: 'nend|run 0|add 0 0 3 2 0 0 0 0 0|mld4 0|0 0 1 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',        # đưa giá trị đầu trong 32 giá trị sang mem tiếp theo (để bỏ qua tính toán padding)
    696: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    697: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop

    # Xử lý hàng 3
    698: 'nend|sbp 8|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    699: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    700: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',       # loop cho 31 output đầu
    701: 'nend|run 0|add 64 0 0 3 0 0 0 0 0|mld4 0|2 1 1 0|0 0|0 0 0|mst0 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    702: 'nend|run 0|add 192 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    703: 'nend|run 0|add 320 2 4 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    704: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    705: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    706: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    707: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    708: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    709: 'nend|run 0|add 0 0 36 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',   # output thứ 32
    710: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt
    711: 'nend|run 0|add 0 0 6 5 0 0 0 0 0|mld4 0|0 0 1 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',    # đưa giá trị đầu trong 32 giá trị sang mem tiếp theo (để bỏ qua tính toán padding)
    712: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    713: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    # Xử lý hàng 4
    714: 'nend|sbp 8|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    715: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    716: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',       # Xử lý output từ 1 -> 31
    717: 'nend|run 0|add 96 0 0 6 0 0 0 0 0|mld4 0|2 1 1 0|0 0|0 0 0|mst0 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    718: 'nend|run 0|add 224 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    719: 'nend|run 0|add 352 2 7 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',
    720: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    721: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    722: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    723: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    724: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    725: 'nend|run 0|add 0 0 39 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000011100000001110000000111000000011100000001110000000111000000',   #xử lý output 32
    726: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt

    # Đưa các output trong OSP 9, 19, 29, 39, 49, 59 từ địa chỉ 8 đến 39 qua LUT
    # OSP 9
    727: 'nend|run 0|add 0 0 0 8 0 0 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    728: 'nend|run 0|add 0 0 0 9 0 0 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    729: 'nend|run 0|add 0 0 0 10 1 1 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    730: 'nend|run 0|add 0 0 0 11 1 1 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    731: 'nend|run 0|add 0 0 0 12 2 2 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    732: 'nend|run 0|add 0 0 0 13 2 2 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    733: 'nend|run 0|add 0 0 0 14 3 3 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    734: 'nend|run 0|add 0 0 0 15 3 3 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    735: 'nend|run 0|add 0 0 0 16 4 4 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    736: 'nend|run 0|add 0 0 0 17 4 4 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    737: 'nend|run 0|add 0 0 0 18 5 5 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    738: 'nend|run 0|add 0 0 0 19 5 5 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    739: 'nend|run 0|add 0 0 0 20 6 6 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    740: 'nend|run 0|add 0 0 0 21 6 6 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    741: 'nend|run 0|add 0 0 0 22 7 7 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    742: 'nend|run 0|add 0 0 0 23 7 7 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    743: 'nend|run 0|add 0 0 0 24 8 8 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    744: 'nend|run 0|add 0 0 0 25 8 8 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    745: 'nend|run 0|add 0 0 0 26 9 9 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    746: 'nend|run 0|add 0 0 0 27 9 9 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    747: 'nend|run 0|add 0 0 0 28 10 10 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    748: 'nend|run 0|add 0 0 0 29 10 10 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    749: 'nend|run 0|add 0 0 0 30 11 11 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    750: 'nend|run 0|add 0 0 0 31 11 11 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    751: 'nend|run 0|add 0 0 0 32 12 12 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    752: 'nend|run 0|add 0 0 0 33 12 12 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    753: 'nend|run 0|add 0 0 0 34 13 13 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    754: 'nend|run 0|add 0 0 0 35 13 13 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    755: 'nend|run 0|add 0 0 0 36 14 14 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    756: 'nend|run 0|add 0 0 0 37 14 14 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    757: 'nend|run 0|add 0 0 0 38 15 15 0 0 0|mld5 9|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    758: 'nend|run 0|add 0 0 0 39 15 15 0 0 0|mld5 9|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # OSP 19
    759: 'nend|run 0|add 0 0 0 8 16 16 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    760: 'nend|run 0|add 0 0 0 9 16 16 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    761: 'nend|run 0|add 0 0 0 10 17 17 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    762: 'nend|run 0|add 0 0 0 11 17 17 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    763: 'nend|run 0|add 0 0 0 12 18 18 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    764: 'nend|run 0|add 0 0 0 13 18 18 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    765: 'nend|run 0|add 0 0 0 14 19 19 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    766: 'nend|run 0|add 0 0 0 15 19 19 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    767: 'nend|run 0|add 0 0 0 16 20 20 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    768: 'nend|run 0|add 0 0 0 17 20 20 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    769: 'nend|run 0|add 0 0 0 18 21 21 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    770: 'nend|run 0|add 0 0 0 19 21 21 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    771: 'nend|run 0|add 0 0 0 20 22 22 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    772: 'nend|run 0|add 0 0 0 21 22 22 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    773: 'nend|run 0|add 0 0 0 22 23 23 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    774: 'nend|run 0|add 0 0 0 23 23 23 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    775: 'nend|run 0|add 0 0 0 24 24 24 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    776: 'nend|run 0|add 0 0 0 25 24 24 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    777: 'nend|run 0|add 0 0 0 26 25 25 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    778: 'nend|run 0|add 0 0 0 27 25 25 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    779: 'nend|run 0|add 0 0 0 28 26 26 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    780: 'nend|run 0|add 0 0 0 29 26 26 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    781: 'nend|run 0|add 0 0 0 30 27 27 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    782: 'nend|run 0|add 0 0 0 31 27 27 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    783: 'nend|run 0|add 0 0 0 32 28 28 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    784: 'nend|run 0|add 0 0 0 33 28 28 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    785: 'nend|run 0|add 0 0 0 34 29 29 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    786: 'nend|run 0|add 0 0 0 35 29 29 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    787: 'nend|run 0|add 0 0 0 36 30 30 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    788: 'nend|run 0|add 0 0 0 37 30 30 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    789: 'nend|run 0|add 0 0 0 38 31 31 1 0 0|mld5 19|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    790: 'nend|run 0|add 0 0 0 39 31 31 1 0 0|mld5 19|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 29
    791: 'nend|run 0|add 0 0 0 8 32 32 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    792: 'nend|run 0|add 0 0 0 9 32 32 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    793: 'nend|run 0|add 0 0 0 10 33 33 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    794: 'nend|run 0|add 0 0 0 11 33 33 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    795: 'nend|run 0|add 0 0 0 12 34 34 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    796: 'nend|run 0|add 0 0 0 13 34 34 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    797: 'nend|run 0|add 0 0 0 14 35 35 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    798: 'nend|run 0|add 0 0 0 15 35 35 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    799: 'nend|run 0|add 0 0 0 16 36 36 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    800: 'nend|run 0|add 0 0 0 17 36 36 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    801: 'nend|run 0|add 0 0 0 18 37 37 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    802: 'nend|run 0|add 0 0 0 19 37 37 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    803: 'nend|run 0|add 0 0 0 20 38 38 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    804: 'nend|run 0|add 0 0 0 21 38 38 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    805: 'nend|run 0|add 0 0 0 22 39 39 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    806: 'nend|run 0|add 0 0 0 23 39 39 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    807: 'nend|run 0|add 0 0 0 24 40 40 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    808: 'nend|run 0|add 0 0 0 25 40 40 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    809: 'nend|run 0|add 0 0 0 26 41 41 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    810: 'nend|run 0|add 0 0 0 27 41 41 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    811: 'nend|run 0|add 0 0 0 28 42 42 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    812: 'nend|run 0|add 0 0 0 29 42 42 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    813: 'nend|run 0|add 0 0 0 30 43 43 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    814: 'nend|run 0|add 0 0 0 31 43 43 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    815: 'nend|run 0|add 0 0 0 32 44 44 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    816: 'nend|run 0|add 0 0 0 33 44 44 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    817: 'nend|run 0|add 0 0 0 34 45 45 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    818: 'nend|run 0|add 0 0 0 35 45 45 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    819: 'nend|run 0|add 0 0 0 36 46 46 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    820: 'nend|run 0|add 0 0 0 37 46 46 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    821: 'nend|run 0|add 0 0 0 38 47 47 2 0 0|mld5 29|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    822: 'nend|run 0|add 0 0 0 39 47 47 2 0 0|mld5 29|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 39
    823: 'nend|run 0|add 0 0 0 8 48 48 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    824: 'nend|run 0|add 0 0 0 9 48 48 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    825: 'nend|run 0|add 0 0 0 10 49 49 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    826: 'nend|run 0|add 0 0 0 11 49 49 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    827: 'nend|run 0|add 0 0 0 12 50 50 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    828: 'nend|run 0|add 0 0 0 13 50 50 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    829: 'nend|run 0|add 0 0 0 14 51 51 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    830: 'nend|run 0|add 0 0 0 15 51 51 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    831: 'nend|run 0|add 0 0 0 16 52 52 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    832: 'nend|run 0|add 0 0 0 17 52 52 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    833: 'nend|run 0|add 0 0 0 18 53 53 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    834: 'nend|run 0|add 0 0 0 19 53 53 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    835: 'nend|run 0|add 0 0 0 20 54 54 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    836: 'nend|run 0|add 0 0 0 21 54 54 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    837: 'nend|run 0|add 0 0 0 22 55 55 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    838: 'nend|run 0|add 0 0 0 23 55 55 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    839: 'nend|run 0|add 0 0 0 24 56 56 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    840: 'nend|run 0|add 0 0 0 25 56 56 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    841: 'nend|run 0|add 0 0 0 26 57 57 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    842: 'nend|run 0|add 0 0 0 27 57 57 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    843: 'nend|run 0|add 0 0 0 28 58 58 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    844: 'nend|run 0|add 0 0 0 29 58 58 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    845: 'nend|run 0|add 0 0 0 30 59 59 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    846: 'nend|run 0|add 0 0 0 31 59 59 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    847: 'nend|run 0|add 0 0 0 32 60 60 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    848: 'nend|run 0|add 0 0 0 33 60 60 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    849: 'nend|run 0|add 0 0 0 34 61 61 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    850: 'nend|run 0|add 0 0 0 35 61 61 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    851: 'nend|run 0|add 0 0 0 36 62 62 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    852: 'nend|run 0|add 0 0 0 37 62 62 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    853: 'nend|run 0|add 0 0 0 38 63 63 3 0 0|mld5 39|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    854: 'nend|run 0|add 0 0 0 39 63 63 3 0 0|mld5 39|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 49
    855: 'nend|run 0|add 0 0 0 8 64 64 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    856: 'nend|run 0|add 0 0 0 9 64 64 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    857: 'nend|run 0|add 0 0 0 10 65 65 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    858: 'nend|run 0|add 0 0 0 11 65 65 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    859: 'nend|run 0|add 0 0 0 12 66 66 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    860: 'nend|run 0|add 0 0 0 13 66 66 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    861: 'nend|run 0|add 0 0 0 14 67 67 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    862: 'nend|run 0|add 0 0 0 15 67 67 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    863: 'nend|run 0|add 0 0 0 16 68 68 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    864: 'nend|run 0|add 0 0 0 17 68 68 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    865: 'nend|run 0|add 0 0 0 18 69 69 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    866: 'nend|run 0|add 0 0 0 19 69 69 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    867: 'nend|run 0|add 0 0 0 20 70 70 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    868: 'nend|run 0|add 0 0 0 21 70 70 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    869: 'nend|run 0|add 0 0 0 22 71 71 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    870: 'nend|run 0|add 0 0 0 23 71 71 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    871: 'nend|run 0|add 0 0 0 24 72 72 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    872: 'nend|run 0|add 0 0 0 25 72 72 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    873: 'nend|run 0|add 0 0 0 26 73 73 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    874: 'nend|run 0|add 0 0 0 27 73 73 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    875: 'nend|run 0|add 0 0 0 28 74 74 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    876: 'nend|run 0|add 0 0 0 29 74 74 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    877: 'nend|run 0|add 0 0 0 30 75 75 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    878: 'nend|run 0|add 0 0 0 31 75 75 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    879: 'nend|run 0|add 0 0 0 32 76 76 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    880: 'nend|run 0|add 0 0 0 33 76 76 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    881: 'nend|run 0|add 0 0 0 34 77 77 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    882: 'nend|run 0|add 0 0 0 35 77 77 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    883: 'nend|run 0|add 0 0 0 36 78 78 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    884: 'nend|run 0|add 0 0 0 37 78 78 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    885: 'nend|run 0|add 0 0 0 38 79 79 4 0 0|mld5 49|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    886: 'nend|run 0|add 0 0 0 39 79 79 4 0 0|mld5 49|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 59
    887: 'nend|run 0|add 0 0 0 8 80 80 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    888: 'nend|run 0|add 0 0 0 9 80 80 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    889: 'nend|run 0|add 0 0 0 10 81 81 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    890: 'nend|run 0|add 0 0 0 11 81 81 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    891: 'nend|run 0|add 0 0 0 12 82 82 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    892: 'nend|run 0|add 0 0 0 13 82 82 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    893: 'nend|run 0|add 0 0 0 14 83 83 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    894: 'nend|run 0|add 0 0 0 15 83 83 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    895: 'nend|run 0|add 0 0 0 16 84 84 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    896: 'nend|run 0|add 0 0 0 17 84 84 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    897: 'nend|run 0|add 0 0 0 18 85 85 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    898: 'nend|run 0|add 0 0 0 19 85 85 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    899: 'nend|run 0|add 0 0 0 20 86 86 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    900: 'nend|run 0|add 0 0 0 21 86 86 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    901: 'nend|run 0|add 0 0 0 22 87 87 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    902: 'nend|run 0|add 0 0 0 23 87 87 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    903: 'nend|run 0|add 0 0 0 24 88 88 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    904: 'nend|run 0|add 0 0 0 25 88 88 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    905: 'nend|run 0|add 0 0 0 26 89 89 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    906: 'nend|run 0|add 0 0 0 27 89 89 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    907: 'nend|run 0|add 0 0 0 28 90 90 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    908: 'nend|run 0|add 0 0 0 29 90 90 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    909: 'nend|run 0|add 0 0 0 30 91 91 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    910: 'nend|run 0|add 0 0 0 31 91 91 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    911: 'nend|run 0|add 0 0 0 32 92 92 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    912: 'nend|run 0|add 0 0 0 33 92 92 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    913: 'nend|run 0|add 0 0 0 34 93 93 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    914: 'nend|run 0|add 0 0 0 35 93 93 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    915: 'nend|run 0|add 0 0 0 36 94 94 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    916: 'nend|run 0|add 0 0 0 37 94 94 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    917: 'nend|run 0|add 0 0 0 38 95 95 5 0 0|mld5 59|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    918: 'nend|run 0|add 0 0 0 39 95 95 5 0 0|mld5 59|0 0 0 0|0 0|5 0 0|mst1 2 0|0',

    919: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt
    920: "end|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
# End Phase 2



# Phase 3
#===================================================================
    # code xử lý hàng 29, 30, 31, pad0
    # Tận dụng cách xử lý hàng 29, 30, 31 như ở trên
    # Viết thêm code để xử lý cho 30, 31, pad0
# Xử lý hàng 30, 31, pad0
    # Xử lý hàng 30
    921: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    922: 'nend|sbp 3|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    923: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    924: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    925: 'nend|run 0|add 32 0 0 0 0 0 0 0 0|mld2 0|2 1 3 0|0 0|0 0 0|mst0 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',
    926: 'nend|run 0|add 160 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',
    927: 'nend|run 0|add 288 2 1 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',      #1 -> 31
    928: 'nend|run 0|add 0 0 33 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000000000011100000001110000000111000000011100000001110000000111',      #32
    929: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',     # reset thanh ghi chốt
    930: 'nend|run 0|add 0 0 3 2 0 0 0 0 0|mld4 0|0 0 1 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',        # đưa giá trị đầu trong 32 giá trị sang mem tiếp theo (để bỏ qua tính toán padding)
    931: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    932: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop

    # Xử lý hàng 31
    933: 'nend|sbp 8|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    934: 'nend|sof 13|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',
    935: 'nend|sit 32|nadd 0 0 0 0 0 0 0 0 0|mld0 0|0 0 0 0|0 0|0 0 0|mst0 1 0|0',       # loop cho 31 output đầu
    936: 'nend|run 0|add 64 0 0 3 0 0 0 0 0|mld4 0|2 1 1 0|0 0|0 0 0|mst0 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    937: 'nend|run 0|add 192 1 0 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst0 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    938: 'nend|run 0|add 320 2 4 0 0 0 0 0 0|mld2 0|2 1 2 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',
    939: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    940: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0", #nop
    941: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    942: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    943: "nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    944: 'nend|run 0|add 0 0 36 0 0 0 0 0 0|mld2 0|0 0 3 0|0 0|0 0 0|mst2 0 0|0b0000000011100000001110000000111000000011100000001110000000111000',   # output thứ 32
    945: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt


    # Đưa các output trong OSP 6, 16, 26, 36, 46, 56 từ địa chỉ 5 đến 36 qua LUT
    # OSP 6
    946: 'nend|run 0|add 0 0 0 5 0 0 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    947: 'nend|run 0|add 0 0 0 6 0 0 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    948: 'nend|run 0|add 0 0 0 7 1 1 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    949: 'nend|run 0|add 0 0 0 8 1 1 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    950: 'nend|run 0|add 0 0 0 9 2 2 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    951: 'nend|run 0|add 0 0 0 10 2 2 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    952: 'nend|run 0|add 0 0 0 11 3 3 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    953: 'nend|run 0|add 0 0 0 12 3 3 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    954: 'nend|run 0|add 0 0 0 13 4 4 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    955: 'nend|run 0|add 0 0 0 14 4 4 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    956: 'nend|run 0|add 0 0 0 15 5 5 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    957: 'nend|run 0|add 0 0 0 16 5 5 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    958: 'nend|run 0|add 0 0 0 17 6 6 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    959: 'nend|run 0|add 0 0 0 18 6 6 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    960: 'nend|run 0|add 0 0 0 19 7 7 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    961: 'nend|run 0|add 0 0 0 20 7 7 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    962: 'nend|run 0|add 0 0 0 21 8 8 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    963: 'nend|run 0|add 0 0 0 22 8 8 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    964: 'nend|run 0|add 0 0 0 23 9 9 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    965: 'nend|run 0|add 0 0 0 24 9 9 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    966: 'nend|run 0|add 0 0 0 25 10 10 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    967: 'nend|run 0|add 0 0 0 26 10 10 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    968: 'nend|run 0|add 0 0 0 27 11 11 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    969: 'nend|run 0|add 0 0 0 28 11 11 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    970: 'nend|run 0|add 0 0 0 29 12 12 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    971: 'nend|run 0|add 0 0 0 30 12 12 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    972: 'nend|run 0|add 0 0 0 31 13 13 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    973: 'nend|run 0|add 0 0 0 32 13 13 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    974: 'nend|run 0|add 0 0 0 33 14 14 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    975: 'nend|run 0|add 0 0 0 34 14 14 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    976: 'nend|run 0|add 0 0 0 35 15 15 0 0 0|mld5 6|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    977: 'nend|run 0|add 0 0 0 36 15 15 0 0 0|mld5 6|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # OSP 16
    978: 'nend|run 0|add 0 0 0 5 16 16 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    979: 'nend|run 0|add 0 0 0 6 16 16 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    980: 'nend|run 0|add 0 0 0 7 17 17 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    981: 'nend|run 0|add 0 0 0 8 17 17 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    982: 'nend|run 0|add 0 0 0 9 18 18 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    983: 'nend|run 0|add 0 0 0 10 18 18 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    984: 'nend|run 0|add 0 0 0 11 19 19 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    985: 'nend|run 0|add 0 0 0 12 19 19 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    986: 'nend|run 0|add 0 0 0 13 20 20 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    987: 'nend|run 0|add 0 0 0 14 20 20 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    988: 'nend|run 0|add 0 0 0 15 21 21 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    989: 'nend|run 0|add 0 0 0 16 21 21 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    990: 'nend|run 0|add 0 0 0 17 22 22 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    991: 'nend|run 0|add 0 0 0 18 22 22 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    992: 'nend|run 0|add 0 0 0 19 23 23 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    993: 'nend|run 0|add 0 0 0 20 23 23 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    994: 'nend|run 0|add 0 0 0 21 24 24 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    995: 'nend|run 0|add 0 0 0 22 24 24 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    996: 'nend|run 0|add 0 0 0 23 25 25 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    997: 'nend|run 0|add 0 0 0 24 25 25 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    998: 'nend|run 0|add 0 0 0 25 26 26 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    999: 'nend|run 0|add 0 0 0 26 26 26 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1000: 'nend|run 0|add 0 0 0 27 27 27 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1001: 'nend|run 0|add 0 0 0 28 27 27 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1002: 'nend|run 0|add 0 0 0 29 28 28 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1003: 'nend|run 0|add 0 0 0 30 28 28 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1004: 'nend|run 0|add 0 0 0 31 29 29 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1005: 'nend|run 0|add 0 0 0 32 29 29 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1006: 'nend|run 0|add 0 0 0 33 30 30 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1007: 'nend|run 0|add 0 0 0 34 30 30 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1008: 'nend|run 0|add 0 0 0 35 31 31 1 0 0|mld5 16|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1009: 'nend|run 0|add 0 0 0 36 31 31 1 0 0|mld5 16|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 26
    1010: 'nend|run 0|add 0 0 0 5 32 32 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1011: 'nend|run 0|add 0 0 0 6 32 32 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1012: 'nend|run 0|add 0 0 0 7 33 33 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1013: 'nend|run 0|add 0 0 0 8 33 33 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1014: 'nend|run 0|add 0 0 0 9 34 34 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1015: 'nend|run 0|add 0 0 0 10 34 34 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1016: 'nend|run 0|add 0 0 0 11 35 35 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1017: 'nend|run 0|add 0 0 0 12 35 35 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1018: 'nend|run 0|add 0 0 0 13 36 36 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1019: 'nend|run 0|add 0 0 0 14 36 36 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1020: 'nend|run 0|add 0 0 0 15 37 37 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1021: 'nend|run 0|add 0 0 0 16 37 37 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1022: 'nend|run 0|add 0 0 0 17 38 38 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1023: 'nend|run 0|add 0 0 0 18 38 38 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1024: 'nend|run 0|add 0 0 0 19 39 39 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1025: 'nend|run 0|add 0 0 0 20 39 39 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1026: 'nend|run 0|add 0 0 0 21 40 40 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1027: 'nend|run 0|add 0 0 0 22 40 40 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1028: 'nend|run 0|add 0 0 0 23 41 41 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1029: 'nend|run 0|add 0 0 0 24 41 41 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1030: 'nend|run 0|add 0 0 0 25 42 42 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1031: 'nend|run 0|add 0 0 0 26 42 42 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1032: 'nend|run 0|add 0 0 0 27 43 43 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1033: 'nend|run 0|add 0 0 0 28 43 43 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1034: 'nend|run 0|add 0 0 0 29 44 44 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1035: 'nend|run 0|add 0 0 0 30 44 44 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1036: 'nend|run 0|add 0 0 0 31 45 45 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1037: 'nend|run 0|add 0 0 0 32 45 45 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1038: 'nend|run 0|add 0 0 0 33 46 46 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1039: 'nend|run 0|add 0 0 0 34 46 46 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1040: 'nend|run 0|add 0 0 0 35 47 47 2 0 0|mld5 26|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1041: 'nend|run 0|add 0 0 0 36 47 47 2 0 0|mld5 26|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 36
    1042: 'nend|run 0|add 0 0 0 5 48 48 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1043: 'nend|run 0|add 0 0 0 6 48 48 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1044: 'nend|run 0|add 0 0 0 7 49 49 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1045: 'nend|run 0|add 0 0 0 8 49 49 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1046: 'nend|run 0|add 0 0 0 9 50 50 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1047: 'nend|run 0|add 0 0 0 10 50 50 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1048: 'nend|run 0|add 0 0 0 11 51 51 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1049: 'nend|run 0|add 0 0 0 12 51 51 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1050: 'nend|run 0|add 0 0 0 13 52 52 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1051: 'nend|run 0|add 0 0 0 14 52 52 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1052: 'nend|run 0|add 0 0 0 15 53 53 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1053: 'nend|run 0|add 0 0 0 16 53 53 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1054: 'nend|run 0|add 0 0 0 17 54 54 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1055: 'nend|run 0|add 0 0 0 18 54 54 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1056: 'nend|run 0|add 0 0 0 19 55 55 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1057: 'nend|run 0|add 0 0 0 20 55 55 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1058: 'nend|run 0|add 0 0 0 21 56 56 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1059: 'nend|run 0|add 0 0 0 22 56 56 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1060: 'nend|run 0|add 0 0 0 23 57 57 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1061: 'nend|run 0|add 0 0 0 24 57 57 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1062: 'nend|run 0|add 0 0 0 25 58 58 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1063: 'nend|run 0|add 0 0 0 26 58 58 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1064: 'nend|run 0|add 0 0 0 27 59 59 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1065: 'nend|run 0|add 0 0 0 28 59 59 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1066: 'nend|run 0|add 0 0 0 29 60 60 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1067: 'nend|run 0|add 0 0 0 30 60 60 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1068: 'nend|run 0|add 0 0 0 31 61 61 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1069: 'nend|run 0|add 0 0 0 32 61 61 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1070: 'nend|run 0|add 0 0 0 33 62 62 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1071: 'nend|run 0|add 0 0 0 34 62 62 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1072: 'nend|run 0|add 0 0 0 35 63 63 3 0 0|mld5 36|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1073: 'nend|run 0|add 0 0 0 36 63 63 3 0 0|mld5 36|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 46
    1074: 'nend|run 0|add 0 0 0 5 64 64 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1075: 'nend|run 0|add 0 0 0 6 64 64 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1076: 'nend|run 0|add 0 0 0 7 65 65 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1077: 'nend|run 0|add 0 0 0 8 65 65 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1078: 'nend|run 0|add 0 0 0 9 66 66 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1079: 'nend|run 0|add 0 0 0 10 66 66 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1080: 'nend|run 0|add 0 0 0 11 67 67 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1081: 'nend|run 0|add 0 0 0 12 67 67 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1082: 'nend|run 0|add 0 0 0 13 68 68 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1083: 'nend|run 0|add 0 0 0 14 68 68 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1084: 'nend|run 0|add 0 0 0 15 69 69 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1085: 'nend|run 0|add 0 0 0 16 69 69 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1086: 'nend|run 0|add 0 0 0 17 70 70 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1087: 'nend|run 0|add 0 0 0 18 70 70 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1088: 'nend|run 0|add 0 0 0 19 71 71 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1089: 'nend|run 0|add 0 0 0 20 71 71 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1090: 'nend|run 0|add 0 0 0 21 72 72 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1091: 'nend|run 0|add 0 0 0 22 72 72 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1092: 'nend|run 0|add 0 0 0 23 73 73 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1093: 'nend|run 0|add 0 0 0 24 73 73 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1094: 'nend|run 0|add 0 0 0 25 74 74 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1095: 'nend|run 0|add 0 0 0 26 74 74 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1096: 'nend|run 0|add 0 0 0 27 75 75 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1097: 'nend|run 0|add 0 0 0 28 75 75 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1098: 'nend|run 0|add 0 0 0 29 76 76 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1099: 'nend|run 0|add 0 0 0 30 76 76 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1100: 'nend|run 0|add 0 0 0 31 77 77 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1101: 'nend|run 0|add 0 0 0 32 77 77 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1102: 'nend|run 0|add 0 0 0 33 78 78 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1103: 'nend|run 0|add 0 0 0 34 78 78 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1104: 'nend|run 0|add 0 0 0 35 79 79 4 0 0|mld5 46|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1105: 'nend|run 0|add 0 0 0 36 79 79 4 0 0|mld5 46|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    # Đọc OSP 56
    1106: 'nend|run 0|add 0 0 0 5 80 80 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1107: 'nend|run 0|add 0 0 0 6 80 80 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1108: 'nend|run 0|add 0 0 0 7 81 81 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1109: 'nend|run 0|add 0 0 0 8 81 81 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1110: 'nend|run 0|add 0 0 0 9 82 82 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1111: 'nend|run 0|add 0 0 0 10 82 82 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1112: 'nend|run 0|add 0 0 0 11 83 83 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1113: 'nend|run 0|add 0 0 0 12 83 83 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1114: 'nend|run 0|add 0 0 0 13 84 84 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1115: 'nend|run 0|add 0 0 0 14 84 84 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1116: 'nend|run 0|add 0 0 0 15 85 85 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1117: 'nend|run 0|add 0 0 0 16 85 85 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1118: 'nend|run 0|add 0 0 0 17 86 86 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1119: 'nend|run 0|add 0 0 0 18 86 86 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1120: 'nend|run 0|add 0 0 0 19 87 87 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1121: 'nend|run 0|add 0 0 0 20 87 87 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1122: 'nend|run 0|add 0 0 0 21 88 88 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1123: 'nend|run 0|add 0 0 0 22 88 88 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1124: 'nend|run 0|add 0 0 0 23 89 89 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1125: 'nend|run 0|add 0 0 0 24 89 89 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1126: 'nend|run 0|add 0 0 0 25 90 90 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1127: 'nend|run 0|add 0 0 0 26 90 90 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1128: 'nend|run 0|add 0 0 0 27 91 91 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1129: 'nend|run 0|add 0 0 0 28 91 91 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1130: 'nend|run 0|add 0 0 0 29 92 92 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1131: 'nend|run 0|add 0 0 0 30 92 92 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1132: 'nend|run 0|add 0 0 0 31 93 93 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1133: 'nend|run 0|add 0 0 0 32 93 93 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1134: 'nend|run 0|add 0 0 0 33 94 94 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1135: 'nend|run 0|add 0 0 0 34 94 94 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',
    1136: 'nend|run 0|add 0 0 0 35 95 95 5 0 0|mld5 56|0 0 0 0|0 0|2 0 0|mst1 2 0|0',
    1137: 'nend|run 0|add 0 0 0 36 95 95 5 0 0|mld5 56|0 0 0 0|0 0|5 0 0|mst1 2 0|0',

    1138: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',  # reset thanh ghi chốt
    1139: "end|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
# End Phase 3
# END CONV0

# DENSE0
    # 1/10 output
    1140: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|1 1 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1141: 'nend|run 0|add 1 1 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1142: 'nend|run 0|add 2 2 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1143: 'nend|run 0|add 3 3 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1144: 'nend|run 0|add 4 4 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1145: 'nend|run 0|add 5 5 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1146: 'nend|run 0|add 6 6 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1147: 'nend|run 0|add 7 7 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1148: 'nend|run 0|add 8 8 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1149: 'nend|run 0|add 9 9 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1150: 'nend|run 0|add 10 10 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1151: 'nend|run 0|add 11 11 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1152: 'nend|run 0|add 12 12 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1153: 'nend|run 0|add 13 13 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1154: 'nend|run 0|add 14 14 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1155: 'nend|run 0|add 15 15 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1156: 'nend|run 0|add 16 16 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1157: 'nend|run 0|add 17 17 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1158: 'nend|run 0|add 18 18 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1159: 'nend|run 0|add 19 19 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1160: 'nend|run 0|add 20 20 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1161: 'nend|run 0|add 21 21 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1162: 'nend|run 0|add 22 22 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1163: 'nend|run 0|add 23 23 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst3 0 0|0xFFFFFFFFFFFFFFFF',

    # 2/10 output
    1164: 'nend|run 0|add 0 24 0 0 0 0 0 0 0|mld2 0|1 1 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1165: 'nend|run 0|add 1 25 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1166: 'nend|run 0|add 2 26 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1167: 'nend|run 0|add 3 27 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1168: 'nend|run 0|add 4 28 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1169: 'nend|run 0|add 5 29 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1170: 'nend|run 0|add 6 30 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1171: 'nend|run 0|add 7 31 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1172: 'nend|run 0|add 8 32 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1173: 'nend|run 0|add 9 33 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1174: 'nend|run 0|add 10 34 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1175: 'nend|run 0|add 11 35 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1176: 'nend|run 0|add 12 36 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1177: 'nend|run 0|add 13 37 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1178: 'nend|run 0|add 14 38 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1179: 'nend|run 0|add 15 39 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1180: 'nend|run 0|add 16 40 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1181: 'nend|run 0|add 17 41 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1182: 'nend|run 0|add 18 42 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1183: 'nend|run 0|add 19 43 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1184: 'nend|run 0|add 20 44 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1185: 'nend|run 0|add 21 45 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1186: 'nend|run 0|add 22 46 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1187: 'nend|run 0|add 23 47 0 0 0 0 0 1 0|mld2 0|1 1 2 0|0 0|0 0 0|mst3 0 0|0xFFFFFFFFFFFFFFFF',

    # 3/10 output
    1188: 'nend|run 0|add 0 48 0 0 0 0 0 0 0|mld2 0|1 1 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1189: 'nend|run 0|add 1 49 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1190: 'nend|run 0|add 2 50 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1191: 'nend|run 0|add 3 51 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1192: 'nend|run 0|add 4 52 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1193: 'nend|run 0|add 5 53 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1194: 'nend|run 0|add 6 54 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1195: 'nend|run 0|add 7 55 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1196: 'nend|run 0|add 8 56 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1197: 'nend|run 0|add 9 57 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1198: 'nend|run 0|add 10 58 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1199: 'nend|run 0|add 11 59 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1200: 'nend|run 0|add 12 60 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1201: 'nend|run 0|add 13 61 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1202: 'nend|run 0|add 14 62 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1203: 'nend|run 0|add 15 63 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1204: 'nend|run 0|add 16 64 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1205: 'nend|run 0|add 17 65 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1206: 'nend|run 0|add 18 66 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1207: 'nend|run 0|add 19 67 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1208: 'nend|run 0|add 20 68 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1209: 'nend|run 0|add 21 69 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1210: 'nend|run 0|add 22 70 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1211: 'nend|run 0|add 23 71 0 0 0 0 0 2 0|mld2 0|1 1 2 0|0 0|0 0 0|mst3 0 0|0xFFFFFFFFFFFFFFFF',

    # 4/10 output
    1212: 'nend|run 0|add 0 72 0 0 0 0 0 0 0|mld2 0|1 1 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1213: 'nend|run 0|add 1 73 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1214: 'nend|run 0|add 2 74 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1215: 'nend|run 0|add 3 75 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1216: 'nend|run 0|add 4 76 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1217: 'nend|run 0|add 5 77 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1218: 'nend|run 0|add 6 78 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1219: 'nend|run 0|add 7 79 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1220: 'nend|run 0|add 8 80 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1221: 'nend|run 0|add 9 81 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1222: 'nend|run 0|add 10 82 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1223: 'nend|run 0|add 11 83 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1224: 'nend|run 0|add 12 84 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1225: 'nend|run 0|add 13 85 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1226: 'nend|run 0|add 14 86 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1227: 'nend|run 0|add 15 87 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1228: 'nend|run 0|add 16 88 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1229: 'nend|run 0|add 17 89 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1230: 'nend|run 0|add 18 90 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1231: 'nend|run 0|add 19 91 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1232: 'nend|run 0|add 20 92 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1233: 'nend|run 0|add 21 93 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1234: 'nend|run 0|add 22 94 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1235: 'nend|run 0|add 23 95 0 0 0 0 0 3 0|mld2 0|1 1 2 0|0 0|0 0 0|mst3 0 0|0xFFFFFFFFFFFFFFFF',

    # 5/10 output
    1236: 'nend|run 0|add 0 96 0 0 0 0 0 0 0|mld2 0|1 1 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1237: 'nend|run 0|add 1 97 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1238: 'nend|run 0|add 2 98 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1239: 'nend|run 0|add 3 99 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1240: 'nend|run 0|add 4 100 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1241: 'nend|run 0|add 5 101 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1242: 'nend|run 0|add 6 102 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1243: 'nend|run 0|add 7 103 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1244: 'nend|run 0|add 8 104 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1245: 'nend|run 0|add 9 105 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1246: 'nend|run 0|add 10 106 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1247: 'nend|run 0|add 11 107 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1248: 'nend|run 0|add 12 108 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1249: 'nend|run 0|add 13 109 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1250: 'nend|run 0|add 14 110 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1251: 'nend|run 0|add 15 111 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1252: 'nend|run 0|add 16 112 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1253: 'nend|run 0|add 17 113 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1254: 'nend|run 0|add 18 114 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1255: 'nend|run 0|add 19 115 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1256: 'nend|run 0|add 20 116 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1257: 'nend|run 0|add 21 117 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1258: 'nend|run 0|add 22 118 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1259: 'nend|run 0|add 23 119 0 0 0 0 0 4 0|mld2 0|1 1 2 0|0 0|0 0 0|mst3 0 0|0xFFFFFFFFFFFFFFFF',

    # 6/10 output
    1260: 'nend|run 0|add 0 120 0 0 0 0 0 0 0|mld2 0|1 1 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1261: 'nend|run 0|add 1 121 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1262: 'nend|run 0|add 2 122 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1263: 'nend|run 0|add 3 123 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1264: 'nend|run 0|add 4 124 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1265: 'nend|run 0|add 5 125 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1266: 'nend|run 0|add 6 126 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1267: 'nend|run 0|add 7 127 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1268: 'nend|run 0|add 8 128 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1269: 'nend|run 0|add 9 129 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1270: 'nend|run 0|add 10 130 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1271: 'nend|run 0|add 11 131 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1272: 'nend|run 0|add 12 132 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1273: 'nend|run 0|add 13 133 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1274: 'nend|run 0|add 14 134 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1275: 'nend|run 0|add 15 135 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1276: 'nend|run 0|add 16 136 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1277: 'nend|run 0|add 17 137 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1278: 'nend|run 0|add 18 138 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1279: 'nend|run 0|add 19 139 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1280: 'nend|run 0|add 20 140 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1281: 'nend|run 0|add 21 141 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1282: 'nend|run 0|add 22 142 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1283: 'nend|run 0|add 23 143 0 0 0 0 0 5 0|mld2 0|1 1 2 0|0 0|0 0 0|mst3 0 0|0xFFFFFFFFFFFFFFFF',

    # 7/10 output
    1284: 'nend|run 0|add 0 144 0 0 0 0 0 0 0|mld2 0|1 1 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1285: 'nend|run 0|add 1 145 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1286: 'nend|run 0|add 2 146 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1287: 'nend|run 0|add 3 147 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1288: 'nend|run 0|add 4 148 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1289: 'nend|run 0|add 5 149 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1290: 'nend|run 0|add 6 150 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1291: 'nend|run 0|add 7 151 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1292: 'nend|run 0|add 8 152 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1293: 'nend|run 0|add 9 153 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1294: 'nend|run 0|add 10 154 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1295: 'nend|run 0|add 11 155 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1296: 'nend|run 0|add 12 156 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1297: 'nend|run 0|add 13 157 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1298: 'nend|run 0|add 14 158 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1299: 'nend|run 0|add 15 159 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1300: 'nend|run 0|add 16 160 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1301: 'nend|run 0|add 17 161 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1302: 'nend|run 0|add 18 162 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1303: 'nend|run 0|add 19 163 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1304: 'nend|run 0|add 20 164 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1305: 'nend|run 0|add 21 165 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1306: 'nend|run 0|add 22 166 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1307: 'nend|run 0|add 23 167 0 0 0 0 0 6 0|mld2 0|1 1 2 0|0 0|0 0 0|mst3 0 0|0xFFFFFFFFFFFFFFFF',

    # 8/10 output
    1308: 'nend|run 0|add 0 168 0 0 0 0 0 0 0|mld2 0|1 1 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1309: 'nend|run 0|add 1 169 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1310: 'nend|run 0|add 2 170 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1311: 'nend|run 0|add 3 171 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1312: 'nend|run 0|add 4 172 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1313: 'nend|run 0|add 5 173 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1314: 'nend|run 0|add 6 174 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1315: 'nend|run 0|add 7 175 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1316: 'nend|run 0|add 8 176 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1317: 'nend|run 0|add 9 177 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1318: 'nend|run 0|add 10 178 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1319: 'nend|run 0|add 11 179 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1320: 'nend|run 0|add 12 180 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1321: 'nend|run 0|add 13 181 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1322: 'nend|run 0|add 14 182 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1323: 'nend|run 0|add 15 183 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1324: 'nend|run 0|add 16 184 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1325: 'nend|run 0|add 17 185 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1326: 'nend|run 0|add 18 186 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1327: 'nend|run 0|add 19 187 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1328: 'nend|run 0|add 20 188 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1329: 'nend|run 0|add 21 189 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1330: 'nend|run 0|add 22 190 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1331: 'nend|run 0|add 23 191 0 0 0 0 0 7 0|mld2 0|1 1 2 0|0 0|0 0 0|mst3 0 0|0xFFFFFFFFFFFFFFFF',

    # 9/10 output
    1332: 'nend|run 0|add 0 192 0 0 0 0 0 0 0|mld2 0|1 1 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1333: 'nend|run 0|add 1 193 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1334: 'nend|run 0|add 2 194 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1335: 'nend|run 0|add 3 195 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1336: 'nend|run 0|add 4 196 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1337: 'nend|run 0|add 5 197 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1338: 'nend|run 0|add 6 198 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1339: 'nend|run 0|add 7 199 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1340: 'nend|run 0|add 8 200 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1341: 'nend|run 0|add 9 201 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1342: 'nend|run 0|add 10 202 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1343: 'nend|run 0|add 11 203 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1344: 'nend|run 0|add 12 204 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1345: 'nend|run 0|add 13 205 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1346: 'nend|run 0|add 14 206 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1347: 'nend|run 0|add 15 207 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1348: 'nend|run 0|add 16 208 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1349: 'nend|run 0|add 17 209 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1350: 'nend|run 0|add 18 210 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1351: 'nend|run 0|add 19 211 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1352: 'nend|run 0|add 20 212 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1353: 'nend|run 0|add 21 213 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1354: 'nend|run 0|add 22 214 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1355: 'nend|run 0|add 23 215 0 0 0 0 0 8 0|mld2 0|1 1 2 0|0 0|0 0 0|mst3 0 0|0xFFFFFFFFFFFFFFFF',

    # 10/10 output
    1356: 'nend|run 0|add 0 216 0 0 0 0 0 0 0|mld2 0|1 1 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1357: 'nend|run 0|add 1 217 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1358: 'nend|run 0|add 2 218 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1359: 'nend|run 0|add 3 219 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1360: 'nend|run 0|add 4 220 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1361: 'nend|run 0|add 5 221 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1362: 'nend|run 0|add 6 222 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1363: 'nend|run 0|add 7 223 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1364: 'nend|run 0|add 8 224 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1365: 'nend|run 0|add 9 225 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1366: 'nend|run 0|add 10 226 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1367: 'nend|run 0|add 11 227 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1368: 'nend|run 0|add 12 228 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1369: 'nend|run 0|add 13 229 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1370: 'nend|run 0|add 14 230 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1371: 'nend|run 0|add 15 231 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1372: 'nend|run 0|add 16 232 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1373: 'nend|run 0|add 17 233 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1374: 'nend|run 0|add 18 234 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1375: 'nend|run 0|add 19 235 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1376: 'nend|run 0|add 20 236 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1377: 'nend|run 0|add 21 237 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1378: 'nend|run 0|add 22 238 0 0 0 0 0 0 0|mld2 0|1 1 2 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',
    1379: 'nend|run 0|add 23 239 0 0 0 0 0 9 0|mld2 0|1 1 2 0|0 0|0 0 0|mst3 0 0|0xFFFFFFFFFFFFFFFF',
    # Softmax
    1380: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld6 0|0 0 0 1|1 0|0 0 0|mst1 3 0|0',
    1381: 'nend|run 0|add 0 0 0 0 1 0 1 0 1|mld6 0|0 0 0 1|1 0|0 0 0|mst1 3 0|0',
    1382: 'nend|run 0|add 0 0 0 0 2 0 2 0 2|mld6 0|0 0 0 1|1 0|0 0 0|mst1 3 0|0',
    1383: 'nend|run 0|add 0 0 0 0 3 0 3 0 3|mld6 0|0 0 0 1|1 0|0 0 0|mst1 3 0|0',
    1384: 'nend|run 0|add 0 0 0 0 4 0 4 0 4|mld6 0|0 0 0 1|1 0|0 0 0|mst1 3 0|0',
    1385: 'nend|run 0|add 0 0 0 0 5 0 5 0 5|mld6 0|0 0 0 1|1 0|0 0 0|mst1 3 0|0',
    1386: 'nend|run 0|add 0 0 0 0 6 0 6 0 6|mld6 0|0 0 0 1|1 0|0 0 0|mst1 3 0|0',
    1387: 'nend|run 0|add 0 0 0 0 7 0 7 0 7|mld6 0|0 0 0 1|1 0|0 0 0|mst1 3 0|0',
    1388: 'nend|run 0|add 0 0 0 0 8 0 8 0 8|mld6 0|0 0 0 1|1 0|0 0 0|mst1 3 0|0',
    1389: 'nend|run 0|add 0 0 0 0 9 0 9 0 9|mld6 0|0 0 0 1|1 0|0 0 0|mst1 3 0|0',

    1390: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF', # reset thanh ghi chốt
    1391: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',# reset thanh ghi chốt
    1392: 'nend|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0xFFFFFFFFFFFFFFFF',# reset thanh ghi chốt

    1393: "end|run 0|add 0 0 0 0 0 0 0 0 0|mld2 0|0 0 0 0|0 0|0 0 0|mst0 0 0|0",  # nop
    # END DENSE0

}

output_file_path = "testfile/DNN_instruction/instructions_0.txt"
with open(output_file_path, "w") as file:
    for key, instruction in instructions.items():
    # Tách mảng dựa trên ký tự '|'
        all_slots = instruction.split('|')
        slot0 = all_slots[0].split(' ')
        slot0_binary = compile_slot0(slot0)

        slot1 = all_slots[1].split(' ')
        slot1_binary = compile_slot1(slot1)

        slot2 = all_slots[2].split(' ')
        slot2_binary = compile_slot2(slot2)

        slot3 = all_slots[3].split(' ')
        slot3_binary = compile_slot3(slot3)

        slot4 = all_slots[4].split(' ')
        slot4_binary = compile_slot4(slot4)

        slot5 = all_slots[5].split(' ')
        slot5_binary = compile_slot5(slot5)

        slot6 = all_slots[6].split(' ')
        slot6_binary = compile_slot6(slot6)

        slot7 = all_slots[7].split(' ')
        slot7_binary = compile_slot7(slot7)

        # print(int((all_slots[8].split(' '))[0]))
        slot_temp_binary = decimal_to_binary_64bit(all_slots[8].split(' '))
        # print(len(slot_temp_binary))
        instruction_bin = slot_temp_binary + slot0_binary + slot1_binary + slot2_binary + slot3_binary + slot4_binary + slot5_binary + slot6_binary + slot7_binary
        # chuoi0 = 123 * '0'
        # print((instruction_bin))
        # Mở file ở chế độ ghi
        # print(len(instruction_bin))
        # for PC, instruction in instructions.items():
            # Xử lý để chuyển instruction sang dạng binary
            # instruction_binary = pre_processing(instruction)

            # Ghi vào file
        file.write(f"{instruction_bin}\n")
        # print(len(instruction_bin))

