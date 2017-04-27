class Cockroach < Formula
  desc "Distributed SQL database"
  homepage "https://www.cockroachlabs.com"
  version "beta-20170420"
  url "https://binaries.cockroachdb.com/cockroach-beta-20170420.src.tgz"
  sha256 "5eb815626d1165e7973169ba7098534dd374f0934a20e59b186d6be4e5602a87"
  head "https://github.com/cockroachdb/cockroach.git"

  depends_on "cmake" => :build
  depends_on "go" => :build
  depends_on "xz" => :build

  patch :DATA

  def install
    ENV["GOPATH"] = buildpath
    system "make", "install"
    bin.install "bin/cockroach" => "cockroach"
  end

  def caveats; <<-EOS.undent
    CockroachDB is a distributed database intended for multi-server deployments.
    For local development only, this formula ships a launchd configuration to
    start a single-node cluster that stores its data under:
      #{var}/cockroach/
    Instead of the default port of 8080, the node serves its admin UI at:
      #{Formatter.url('http://localhost:26256')}

    Do NOT use this cluster to store data you care about; it runs in insecure
    mode and may expose data publicly in e.g. a DNS rebinding attack. To run
    CockroachDB securely, please see:
      #{Formatter.url('https://www.cockroachlabs.com/docs/secure-a-cluster.html')}
    EOS
  end

  plist_options :manual => "cockroach start"

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/cockroach</string>
        <string>start</string>
        <string>--store=#{var}/cockroach/</string>
        <string>--http-port=26256</string>
        <string>--insecure</string>
        <string>--host=localhost</string>
      </array>
      <key>WorkingDirectory</key>
      <string>#{var}</string>
      <key>RunAtLoad</key>
      <true/>
      <key>KeepAlive</key>
      <true/>
    </dict>
    </plist>
    EOS
  end

  test do
    begin
      system "#{bin}/cockroach", "start", "--background"
      pipe_output("#{bin}/cockroach sql", <<-EOS.undent)
        CREATE DATABASE bank;
        CREATE TABLE bank.accounts (id INT PRIMARY KEY, balance DECIMAL);
        INSERT INTO bank.accounts VALUES (1, 1000.50);
      EOS
      output = pipe_output("#{bin}/cockroach sql --format=csv",
        "SELECT * FROM bank.accounts;")
      assert_equal <<-EOS.undent, output
        1 row
        id,balance
        1,1000.50
      EOS
    ensure
      system "#{bin}/cockroach", "quit"
    end
  end
end
__END__
From 0175f03ecdec9f02e4502dd69c53a775a58c3195 Mon Sep 17 00:00:00 2001
From: Nikhil Benesch <nikhil.benesch@gmail.com>
Date: Thu, 20 Apr 2017 19:06:14 -0400
Subject: [PATCH] build: explicitly specify paths to vendored jemalloc

Otherwise, when building with Homebrew on a system with jemalloc
installed, /usr/local/include/jemalloc.h will take precedence over our
bundled jemalloc, and missing symbols abound.
---
 build/common.mk | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/build/common.mk b/build/common.mk
index a8bca56ed..1cd0e7c46 100644
--- a/src/github.com/cockroachdb/cockroach/build/common.mk
+++ b/src/github.com/cockroachdb/cockroach/build/common.mk
@@ -340,7 +340,7 @@ $(ROCKSDB_DIR)/Makefile: $(C_DEPS_DIR)/rocksdb.src.tar.xz | libsnappy libjemallo
 	cd $(ROCKSDB_DIR) && cmake $(CMAKE_FLAGS) $(ROCKSDB_SRC_DIR) \
 	  $(if $(findstring release,$(TYPE)),-DWITH_$(if $(ISWINDOWS),AVX2,SSE42)=ON) \
 	  -DSNAPPY_LIBRARIES=$(SNAPPY_DIR)/.libs/libsnappy.a -DSNAPPY_INCLUDE_DIR=$(SNAPPY_SRC_DIR) -DWITH_SNAPPY=ON \
-	  -DJEMALLOC_ROOT_DIR=$(JEMALLOC_DIR) -DWITH_JEMALLOC=ON
+	  -DJEMALLOC_LIBRARIES=$(JEMALLOC_DIR)/lib/libjemalloc.a -DJEMALLOC_INCLUDE_DIR=$(JEMALLOC_DIR)/include -DWITH_JEMALLOC=ON
 
 $(SNAPPY_DIR)/Makefile: $(C_DEPS_DIR)/snappy.src.tar.xz | $(SNAPPY_SRC_DIR)
 	mkdir -p $(SNAPPY_DIR)
-- 
2.12.1

