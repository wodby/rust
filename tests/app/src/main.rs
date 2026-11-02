use std::io::{Read, Write};
use std::net::TcpListener;

fn main() {
    let listener = TcpListener::bind("0.0.0.0:8080").expect("bind port 8080");
    for stream in listener.incoming() {
        let Ok(mut stream) = stream else { continue };
        let mut request = [0; 1024];
        let _ = stream.read(&mut request);
        let body = "Rust test app\n";
        let _ = write!(
            stream,
            "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
            body.len(),
            body
        );
    }
}
