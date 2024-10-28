# Selfhost Setup Utils
A collection of standalone installation scripts and packages designed to simplify the setup of various services on my Alpine Linux arm64 server.

## Usage
To download and execute a script from this repository, use the following command:

```bash
wget -qO- https://raw.githubusercontent.com/ShuttleTydirium/selfhost_setup_utils/main/scripts/<script_name>.sh | sh
```

## Note
I'm looking to self-host several applications on a lightweight embedded server, and I prefer using LXC over Docker to save on space. The downside is that most self-hosted apps come packaged as Docker images, and they often don't include instructions for bare-metal installations. To work around this, I went through the Dockerfiles for the appications I needed and created shell and init scripts that mimic the build and installation steps found in those Docker images.

These scripts were designed for Alpine Linux (arm64) and tested using v3.20, so they might not work as expected on other versions.

## Contributing
Feel free to use and modify the scripts as needed. There are no formal restrictions or licenses; they are completely libre and free to use.