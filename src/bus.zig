const Err = enum {
    Byte_Size_Err,
};

pub fn fetch_mem(addr: u32, byte_size: u3) !u32 {
    if (byte_size != 1 or byte_size != 2 or byte_size != 4) {
        return Err.Byte_Size_Err;
    }

}
