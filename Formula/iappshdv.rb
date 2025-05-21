class Iappshdv < Formula
  desc "iOS/macOS Application Development Helper and Verification Tool"
  homepage "https://github.com/username/iappshdv"
  url "https://github.com/username/iappshdv/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "YOUR_SHA256_HERE" # You'll need to replace this with the actual checksum
  license "MIT"
  
  depends_on :macos
  depends_on "coreutils"
  
  def install
    # Create necessary directories
    bin.install "bin/iappshdv"
    
    # Install only the necessary library files
    libexec.install Dir["lib/*"]
    
    # Install completions if they exist
    bash_completion.install "completions/iappshdv.bash" if File.exist?("completions/iappshdv.bash")
    zsh_completion.install "completions/iappshdv.zsh" if File.exist?("completions/iappshdv.zsh")
    
    # Install documentation files
    doc.install "README.md", "HOMEBREW.md"
    
    # Install manual pages if they exist
    man1.install Dir["man/*"] if Dir.exist?("man")
    
    # Replace references to lib/ with libexec/
    inreplace bin/"iappshdv", /LIB_DIR=.*/, "LIB_DIR=\"#{libexec}\""
    
    # Note: legacy/ directory is intentionally excluded from installation
  end
  
  def caveats
    <<~EOS
      iappshdv is a tool designed for iOS/macOS app development.
      
      Some features require additional dependencies, which can be installed with:
        iappshdv setup prereqs
        iappshdv setup env
      
      For more information, run:
        iappshdv help
    EOS
  end
  
  test do
    assert_match "iappshdv version", shell_output("#{bin}/iappshdv version")
  end
end 