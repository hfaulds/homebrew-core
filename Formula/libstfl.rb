class Libstfl < Formula
  desc "Library implementing a curses-based widget set for terminals"
  homepage "http://www.clifford.at/stfl/"
  url "http://www.clifford.at/stfl/stfl-0.24.tar.gz"
  sha256 "d4a7aa181a475aaf8a8914a8ccb2a7ff28919d4c8c0f8a061e17a0c36869c090"
  revision 11

  livecheck do
    url :homepage
    regex(/href=.*?stfl[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    cellar :any
    sha256 "c3be3f27c3e229104c33221d6552f025780dddcad0bb510df99f5eb5216f152a" => :big_sur
    sha256 "88c1e85e1cfe0576d472d169e2d6c918c194c38b055a1c4b8c2db5f148400eb9" => :arm64_big_sur
    sha256 "6c2efe2840c84e8f37c56771f2e05f995a495ccbc9688d7af6dd7e993eee2525" => :catalina
    sha256 "c6f9a115588e219c10c9b532b332ffb382fbb217d299f09c803b35ebe426ed1c" => :mojave
    sha256 "63092cebd3e9f26be516acfe3ec11af61dec8b9769fd87eec9fca4334c3e3c96" => :high_sierra
  end

  depends_on "swig" => :build
  depends_on "python@3.9"
  depends_on "ruby"

  uses_from_macos "perl"

  def install
    ENV.prepend_path "PATH", Formula["python@3.9"].opt_libexec/"bin"

    ENV.append "LDLIBS", "-liconv"
    ENV.append "LIBS", "-lncurses -liconv -lruby"

    %w[
      stfl.pc.in
      perl5/Makefile.PL
      ruby/Makefile.snippet
    ].each do |f|
      inreplace f, "ncursesw", "ncurses"
    end

    inreplace "stfl_internals.h", "ncursesw/ncurses.h", "ncurses.h"

    inreplace "Makefile" do |s|
      s.gsub! "ncursesw", "ncurses"
      s.gsub! "-Wl,-soname,$(SONAME)", "-Wl"
      s.gsub! "libstfl.so.$(VERSION)", "libstfl.$(VERSION).dylib"
      s.gsub! "libstfl.so", "libstfl.dylib"
    end

    xy = "3.8"
    python_config = Formula["python@3.9"].opt_libexec/"bin/python-config"

    inreplace "python/Makefile.snippet" do |s|
      # Install into the site-packages in the Cellar (so uninstall works)
      s.change_make_var! "PYTHON_SITEARCH", lib/"python#{xy}/site-packages"
      s.gsub! "lib-dynload/", ""
      s.gsub! "ncursesw", "ncurses"
      s.gsub! "gcc", "gcc -undefined dynamic_lookup #{`#{python_config} --cflags`.chomp}"
      s.gsub! "-lncurses", "-lncurses -liconv"
    end

    # Fails race condition of test:
    #   ImportError: dynamic module does not define init function (init_stfl)
    #   make: *** [python/_stfl.so] Error 1
    ENV.deparallelize

    system "make"

    inreplace "perl5/Makefile", "Network/Library", libexec/"lib/perl5"
    system "make", "install", "prefix=#{prefix}"
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <stfl.h>
      int main() {
        stfl_ipool * pool = stfl_ipool_create("utf-8");
        stfl_ipool_destroy(pool);
        return 0;
      }
    EOS
    system ENV.cxx, "test.cpp", "-L#{lib}", "-lstfl", "-o", "test"
    system "./test"
  end
end
