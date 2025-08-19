Install the Virtual Box
Dedicate 300GB hard drive memory
The RAM: 8GB+


In the Virtual Box make sure the network setting the adaptor1 is selected as bridged adaptor and the right name is selected (find with trial and error / or in host machine run the ifconfig if ubuntu). 

Here’s a clean **README.md** draft you can drop into your repo or VM notes. I’ve kept it concise but complete, and tailored it to your config-based, headless install flow.

---

# Vivado Installation Guide (Ubuntu VM)

This guide explains how to install **Xilinx Vivado ML Standard** on Ubuntu (VM or bare metal) using a pre-generated configuration file for a fully **headless, non-GUI install**.

---

## 📦 Requirements

* Ubuntu 20.04/22.04 (64-bit)
* At least **50 GB free disk space**
* Internet access for downloading payloads
* Vivado Unified Installer (`Xilinx_Unified_2024.1_*.bin`)

Install required dependencies:

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential dkms linux-headers-$(uname -r) \
    libtinfo5 libncurses5 \
    ca-certificates curl xz-utils file
```

---

## ⚙️ Installation Steps

1. **Download the Vivado installer**
   Get the `.bin` file from [AMD/Xilinx Downloads](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive.html).

   ```bash
   chmod +x Xilinx_Unified_2024.1_*.bin
   ```

2. **Save the configuration file**
   Example path:

   ```
   ~/vivado_install.cfg
   ```

   (Your config file should contain Edition, Modules, and Destination, as shown in this repo.)

3. **Run headless installer**

   ```bash
    sudo ./xsetup  -a XilinxEULA,3rdPartyEULA   -b Install  -c install_config.txt

   ```

   > This installs Vivado to `/opt/Xilinx` (as required for ARTIQ).

4. **Update PATH**

   ```bash
   echo 'export PATH=/opt/Xilinx/Vivado/2024.1/bin:$PATH' >> ~/.bashrc
   source ~/.bashrc
   ```

5. **Verify install**

   ```bash
   vivado -mode batch -nolog -nojournal -version
   ```

   You should see the installed version printed.

---

## 🛠️ Troubleshooting

* **Permission denied at `/opt/Xilinx`**
  Run installer with `sudo` or ensure the directory is writable:

  ```bash
  sudo mkdir -p /opt/Xilinx
  sudo chown -R $(id -u):$(id -g) /opt/Xilinx
  ```

* **Mouse integration freezes in VM**
  Run the install over SSH to avoid GUI/mouse issues.

* **Missing libraries**
  Install `libtinfo5` and `libncurses5`:

  ```bash
  sudo apt-get install libtinfo5 libncurses5
  ```

---

## ✅ Summary

This setup installs Vivado silently using a config file and makes it available system-wide from `/opt/Xilinx`. It is optimized for reproducibility and integration with **ARTIQ**.

---

Would you like me to also add a **section for creating your own config file** (so others can replicate without needing yours), or keep it minimal with just the provided one?
