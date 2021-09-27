# This script is unused because filebeat has been configured to work with
# containers having a TTY and thus not needed docker logs demultiplexing.
# In case you need to demultiplex them, this is more or less what is
# needed.errrrr
import sys, struct


def process_header(data: bytes) -> int:
    type = int(data[0])
    length = struct.unpack_from(">I", data, 4)
    return type, length[0]


while True:
    h_data = sys.stdin.buffer.read(8)
    if h_data:
        type, body_len = process_header(h_data)
        # sys.stdout.write(f"type {type}, len {body_len}")
        # sys.stdout.flush()

        b_data = sys.stdin.buffer.read(body_len)

        if b_data and type == 1:
            # stdout
            sys.stdout.buffer.write(b_data)
            sys.stdout.flush()

        if b_data and type == 2:
            # stderr
            sys.stderr.buffer.write(b_data)
            sys.stderr.flush()