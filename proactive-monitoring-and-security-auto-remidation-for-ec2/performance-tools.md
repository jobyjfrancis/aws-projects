# What is the `stress` tool?

`stress` is a workload generator designed to subject your system to a configurable measure of CPU, memory, I/O, and disk stress.

It's particularly useful for testing how systems perform under heavy load and for verifying monitoring systems.

# How we'll use it:

The `stress` command allows us to artificially increase CPU utilization to trigger our `HighCPU` alarm.

When we run `sudo stress --cpu 8 --timeout 600`, it will:

* Create 8 worker processes that perform continuous CPU-intensive calculations
* Each worker will push a CPU core to near 100% utilization
* The workers will automatically terminate after 600 seconds (10 minutes)
* On a typical t3.micro instance with 1-2 vCPUs, this will easily push overall CPU utilization   above our 85% threshold

# Why it's valuable:

It lets us test our monitoring system without having to create actual high-demand workloads

The timeout ensures the test will automatically end, preventing accidental long-term resource consumption

It simulates the kinds of CPU spikes that might occur during real-world incidents like runaway processes or DDoS attacks

# What is util-linux?

`util-linux` is a standard package containing essential system utilities for Linux systems
It includes the `fallocate` command which we'll use to quickly create large files without actually writing data to disk

# How we'll use it:

The `fallocate` command allows us to quickly allocate disk space without actually writing data
When we run `fallocate -l 6G /home/ec2-user/fakefile`, it will:

* Create a 6GB file in the user's home directory
* Reserve this space on the filesystem immediately
* Complete much faster than if we tried to create a file by writing actual data
* On a standard t3.micro with an 8GB volume, this will push disk usage well above our 80% threshold

# Why it's valuable:

It provides a quick, efficient way to simulate disk space issues without generating unnecessary I/O load

Unlike writing actual data with commands like `dd`, fallocate completes almost instantly

It simulates what might happen in production if log files grow unexpectedly or if malicious activity fills disk space

# Safety considerations:

* Both tools allow us to quickly revert to normal operation
* CPU stress automatically stops after the timeout period
* Disk space can be reclaimed immediately by removing the test file
* Neither tool causes permanent damage to the system
* Both tests are designed to trigger alarms without causing actual service disruption

These tools give us a controlled, safe way to verify that our monitoring systems can detect real-world problems and that our automated remediation works as expected.