#!/usr/bin/env python3

"""
This daemon doing simple PostgreSQL check and returns response with information
about PostgreSQL server mode.
"""

import argparse
import re
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer


class PGSQLCheck(BaseHTTPRequestHandler):

    def do_GET(self):
        err, res = self.__psql_cmd('SELECT pg_is_in_recovery()')

        if err != 0:
            self.__return_fail()
            return
        elif re.match(r"(t|true|on|1)", res):
            # if in recovery then slave
            self.__return_ok('slave')
            return

        err, res = self.__psql_cmd('SHOW transaction_read_only')
        if err != 0:
            self.__return_fail()
        elif re.match(r"(f|false|off|0)", res):
            self.__return_ok('master')
        else:
            self.__return_ok('none')

        return

    def __return_ok(self, msg):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write('OK : {}'.format(msg).encode('UTF-8'))
        return

    def __return_fail(self):
        self.send_response(500)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write('Internal Server Error')
        return

    def __psql_cmd(self, cmd):
        cmd = ("echo '{}' | psql -qt {} 2>/dev/null").format(
            cmd, args.connection_string)
        try:
            cmd_result = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, shell=True)
            cmd_stdout = cmd_result.communicate()[0].strip().decode('utf-8')
            cmd_exitcode = cmd_result.returncode
        except CalledProcessError as e:
            print(e.output.decode())

        return [cmd_exitcode, cmd_stdout]

    def log_message(self, format, *args):
        return

def main():
    global args
    parser = argparse.ArgumentParser(
        description=('Daemon that serve http requests and makes simple '
                     'PostgreSQL checks'))
    parser.add_argument("-p", "--port", help="Port to listen on",
                        type=int, default=9000)
    parser.add_argument("-c", "--connection_string",
                        help="PostgreSQL connection string",
                        default=("postgresql://postgres@localhost/"
                                 "postgres?sslmode=disable"))
    args = parser.parse_args()

    try:
        server = HTTPServer(('', args.port), PGSQLCheck)
        print('Started httpserver on port {}'.format(args.port))

        server.serve_forever()

    except KeyboardInterrupt:
        print('^C received, shutting down the web server')
        server.socket.close()


if __name__ == "__main__":
    main()
