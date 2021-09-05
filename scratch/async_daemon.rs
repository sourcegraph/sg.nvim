extern crate rmp;
use futures::{AsyncWriteExt, TryStreamExt};
use interprocess::nonblocking::local_socket::{LocalSocketListener, LocalSocketStream};
use std::error::Error;
use std::io::Write;
use tokio::runtime::Handle;

#[derive(Debug)]
struct WriteableListener {
    handle: Handle,
    conn: LocalSocketStream,
}

impl Write for WriteableListener {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        // futures::executor::block_on(self.conn.write(buf))
        self.handle.block_on(self.conn.write(buf))
    }

    fn flush(&mut self) -> std::io::Result<()> {
        // futures::executor::block_on(self.conn.flush())
        self.handle.block_on(self.conn.flush())
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    println!("We the background thread");

    let handle = Handle::current();

    let listener = LocalSocketListener::bind("/tmp/example.sock").await?;
    listener
        .incoming()
        .try_for_each(|conn| async {
            let handle = handle.clone();

            println!("New connection!");
            let mut conn = WriteableListener { handle, conn };
            let val = rmpv::Value::Array(vec!["hello".into(), "world".into()]);
            rmpv::encode::write_value(&mut conn, &val)?;

            println!("  made it OK");
            Ok(())
        })
        .await?;

    // let listener = LocalSocketListener::bind("/tmp/example.sock")?;
    // println!("{:?}", listener);

    Ok(())
}
