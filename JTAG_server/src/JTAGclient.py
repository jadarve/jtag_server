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


import socket
import re


class JTAGserverError (BaseException):
    
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return repr(self.value)

class JTAGunformattedMessageError (BaseException):
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return repr(self.value)

class JTAGErrorMessageError (BaseException):
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return repr(self.value)

class JTAGclient:
    
    _host = None
    _port = None
    _socket = None
    _connected = False
    _buffersize = 255
    
    def __init__(self, hostName='localhost', port=2000):
        """Set the parameters to connect to the server.
        
        @param hostName: server name or address
        @type hostName: string  
        @param port: server port
        @type port: integer 
        """
        
        self._host = hostName
        self._port = port
        self._connected = False
        
    def connect(self):
        """Connects to the server.
        
        Connect the client object to the JTAG server. In case of error,
        the methods throws a JTAGserverError exception
        """
        try:
            self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self._socket.connect((self._host, self._port))
            self._connected = True
        except socket.error:
            self._connected = False
            raise JTAGserverError("error connecting to: " + str(self._host) + ":" + str(self._port))
    
    def connected(self):
        """Tells whether or not the client is connected.
        
        """
        return self._connected
    
    def sendIR(self, irCode):
        """Sends JTAG IR instruction to the server.
        
        @param irCode: instruction code
        @type irCode: integer  
        """
        if self.connected():
            try:
                irCodeInt = int(irCode)
                #formats the message for the server
                message = "IR:" + str(irCodeInt) + "\n"
                #encode the message to utf-8
                byteArray = bytearray(message, "utf-8")
                self._socket.sendall(byteArray)
                
                #print(message[0:len(message)-1])
                
                #receive the answer from the server
                bufferData = self._socket.recv(self._buffersize);
                
                try:
                    return self._checkIRresponse(bufferData)
                
                except JTAGErrorMessageError:
                    pass
                except JTAGunformattedMessageError:
                    pass
                
            except ValueError:
                raise JTAGserverError('error converting irCode to int')
            except socket.error as e:
                raise JTAGserverError('socket error: ' + e.value)
        else:
            raise JTAGserverError('JTAG adapter not connected to server')
    
    def sendDR(self, value, lengthBytes):
        if self.connected():
            
            try:
                intValue = int(value)
                intLength = int(lengthBytes)
                
                formatOut = "{0:0>{lengthHex}X}"
                strOut = formatOut.format(intValue, lengthHex=(lengthBytes*2))
                
                message = "DR:" + strOut + ":" + str(intLength*8) + "\n"
                
                byteArray = bytearray(message, "utf-8")
                self._socket.sendall(byteArray)
                
                #receive server response
                bufferData = self._socket.recv(self._buffersize)
                
                try:
                    return self._checkDRresponse(bufferData)
                except JTAGErrorMessageError as e:
                    raise JTAGErrorMessageError('DR error: ' + e.value)
                except JTAGunformattedMessageError:
                    raise JTAGserverError('unformatted response from server: ' + str(bufferData, 'utf-8'))
                    
            except ValueError:
                raise JTAGserverError('error converting parameter value or lengthBytes to int')
            except socket.error:
                raise JTAGserverError('socket error')
        else:
            raise JTAGserverError('JTAG adapter not connected to server')


    def _checkDRresponse(self, bufferData):
        strBuffer = str.decode(bufferData, "utf-8")
        
        OKpattern = 'DR:ok:[0-9a-fA-F]+;$'
        ERpattern = 'DR:error:*;$'
        
        if re.match(OKpattern, strBuffer):
            # extract the substring with the return value (-1 to omit the ;)
            strValue = strBuffer[6 : len(strBuffer) - 1]
            intValue = int(strValue, 16)
            return intValue
        elif re.match(ERpattern, strBuffer):
            # extract the error message, if any (-1 to omit the ;)
            strError = strBuffer[9 : len(strBuffer) - 1]
            raise JTAGErrorMessageError(strError)
        else:
            raise JTAGunformattedMessageError(strBuffer)

    def _checkIRresponse(self, bufferData):
        strBuffer = str.decode(bufferData, "utf-8")
        
        OKpattern = 'IR:ok;$'
        ERpattern = 'IR:error:*;$'
        
        if re.match(OKpattern, strBuffer):
            return True
        elif re.match(ERpattern, strBuffer):
            strError = strBuffer[9 : len(strBuffer) - 1]
            raise JTAGErrorMessageError(strError)
        else:
            raise JTAGunformattedMessageError(strBuffer)