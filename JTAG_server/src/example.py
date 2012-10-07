# Copyright (c) 2012 Juan David Adarve
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in 
# the Software without restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
# Software, and to permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

from JTAGclient import JTAGclient
from JTAGclient import JTAGserverError


def main():
    print('test start')
    
    try:
        cAdapter = JTAGclient('localhost', 2000)    # server address and port
        cAdapter.connect()
        
        print('setting LED value')
        cAdapter.sendIR(0x01)               # set LED value instruction
        cAdapter.sendDR(0xAA, 1)            # new LED value
        print('LED value set')
        
        print('getting LED value')
        cAdapter.sendIR(0x02)               # get LED value instruction
        LEDvalue = cAdapter.sendDR(0x00, 1) # read back data from the FPGA
        print('LED value: {0:0>2X}'.format(LEDvalue))
        
    except JTAGserverError as e:
        print(e.value)
    
    print('test completed successfully')

if __name__ == '__main__':
    main()