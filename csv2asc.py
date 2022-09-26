import argparse
import csv
from datetime import datetime
import socket
import struct
import sys

MESSAGE1 = 0x0CF11E05
MESSAGE2 = 0x0CF11F05


def to_log(timeobj, devno, can_id, can_data, transmitted=False):
    out = [
        "%04.6f" % timeobj.timestamp(),
        "can%d" % (devno - 1),
    ]

    data = ".".join("%02X" % d for d in can_data)
    if can_id & socket.CAN_EFF_FLAG:
        out.append("%08X#%s" % (can_id & socket.CAN_EFF_MASK, data))
    else:
        out.append("%03X#%s" % (can_id & socket.CAN_SFF_MASK, data))

    out.append("T" if transmitted else "R")
    return " ".join(out)


def to_asc(timeobj, devno, can_id, can_data, transmitted=False):
    out = [
        "%04.6f" % timeobj.timestamp(),
        "%-2d" % devno
    ]

    if can_id & socket.CAN_ERR_FLAG:
        out.append("ErrorFrame")

    else:
        is_extended = can_id & socket.CAN_EFF_FLAG
        out.append("%X%c" % (can_id & socket.CAN_EFF_MASK,
                             "x" if is_extended else " "))
        out.append("Tx" if transmitted else "Rx")

        if can_id & socket.CAN_RTR_FLAG:
            out.append("r %d" % len(can_data))
        else:
            out.append("d %d" % len(can_data))
            out.extend("%02X" % d for d in can_data)

    return " ".join(out)


def main(argv):
    parser = argparse.ArgumentParser(prog=argv[0])
    parser.add_argument("csv_file", type=argparse.FileType("tr"))
    parser.add_argument("-r", "--relative-time", action="store_true")

    output_format = parser.add_mutually_exclusive_group()
    output_format.add_argument("-a", "--asc", dest="formatter", action="store_const", const=to_asc)
    output_format.add_argument("-l", "--log", dest="formatter", action="store_const", const=to_log)
    parser.set_defaults(formatter=to_log)

    args = parser.parse_args()
    with args.csv_file:
        # Per the `csv.reader` documentation, we should have opened the file
        # with `newline=''`.  Unfortunately `argparse.FileType` does not let
        # us do that but we don't care anyway; we'll only read numbers
        csv_reader = csv.reader(args.csv_file, "unix")

        # read the header (timestamp and column names)
        header_time = next(csv_reader)
        _ = next(csv_reader)

        if args.relative_time:
            base_time = datetime.strptime(
                " ".join(header_time), "%d/%m/%Y %H:%M:%S")
        else:
            base_time = datetime.fromtimestamp(0)

        for row in csv_reader:
            abs_timestamp = datetime.strptime(
                " ".join(row[:3]), "%d/%m/%Y %H:%M:%S %f")
            del row[:3]

            # The last 4 columns are the (calculated) discharge percent and
            # the GPS longitude, latitude and speed; we don't use them
            rpm, throttle, current, voltage, controller_temp, motor_temp, \
                error_code, controller_status, switches_status, *_ = row

            msg1 = struct.pack(
                "<HHHH",
                int(float(rpm)),
                10 * int(float(current)),
                10 * int(float(voltage)),
                int(error_code, 16)
            )

            msg2 = bytes([
                int(throttle),
                40 + int(controller_temp),
                30 + int(motor_temp),
                int(controller_status, 16),
                int(switches_status, 16)
            ])

            timeobj = datetime.fromtimestamp((abs_timestamp - base_time).total_seconds())
            print(args.formatter(timeobj, 1, MESSAGE1 | socket.CAN_EFF_FLAG, msg1))
            print(args.formatter(timeobj, 1, MESSAGE2 | socket.CAN_EFF_FLAG, msg2))


if __name__ == "__main__":
    main(sys.argv)
