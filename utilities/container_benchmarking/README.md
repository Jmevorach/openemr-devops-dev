# Container Benchmarking Utility

## Overview

This benchmarking utility provides a simple, clean way to compare performance between two OpenEMR container images:

- **Image A**: A local build from your repository (default: `./docker/openemr/7.0.5/`)
- **Image B**: A public Docker Hub image (default: `openemr/openemr:7.0.5`)

The benchmark measures:
1. **Startup Time** - How long each container takes to become healthy
2. **Performance Under Load** - Response times and throughput under concurrent requests
3. **Resource Utilization** - CPU and memory usage during load testing

The entire benchmark suite completes in just a few minutes, making it suitable for quick comparisons during development.

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Sufficient system resources (recommended: 4GB+ RAM, 2+ CPU cores)
- Network access to Docker Hub (for pulling Image B)

### Running the Benchmark

1. Navigate to the benchmarking directory:
   ```bash
   cd utilities/container_benchmarking
   ```

2. Run the benchmark script:
   ```bash
   ./benchmark.sh
   ```

3. Wait for completion (typically 3-5 minutes)

4. Review results in the `results/` directory

## Configuration

### Changing Test Images

Edit the configuration variables at the top of `benchmark.sh`:

```bash
# Image A: Local build context (relative to benchmark.sh)
IMAGE_A_CONTEXT="${IMAGE_A_CONTEXT:-../../docker/openemr/7.0.5}"

# Image B: Docker Hub image name and tag
IMAGE_B_IMAGE="${IMAGE_B_IMAGE:-openemr/openemr:7.0.5}"
```

Or set environment variables before running:

```bash
export IMAGE_A_CONTEXT="../../docker/openemr/7.0.4"
export IMAGE_B_IMAGE="openemr/openemr:7.0.4"
./benchmark.sh
```

### Adjusting Load Test Parameters

Modify these variables in `benchmark.sh`:

```bash
LOAD_TEST_CONCURRENT="${LOAD_TEST_CONCURRENT:-10}"    # Concurrent requests
LOAD_TEST_REQUESTS="${LOAD_TEST_REQUESTS:-1000}"       # Total requests
LOAD_TEST_DURATION="${LOAD_TEST_DURATION:-60}"         # Resource monitoring duration (seconds)
```

### Changing Port Mappings

If ports 8080 or 8081 are already in use:

```bash
export IMAGE_A_PORT="9080"
export IMAGE_B_PORT="9081"
./benchmark.sh
```

## Latest Results (November 2025)

Comparing the optimized local build against the Docker Hub image:

| Metric | Image A (Local) | Image B (Docker Hub) | Difference |
|--------|-----------------|----------------------|------------|
| **Startup Time** | 15.0s | 73.1s | **4.9x faster** |
| **Memory (Avg)** | 92.8 MB | 304.2 MB | **69% less** |
| **Memory (Peak)** | 117.1 MB | 326.6 MB | **64% less** |
| **Performance** | 114.9 req/s | 117.2 req/s | Equivalent |
| **Response Time** | 87.1 ms | 85.3 ms | Equivalent |

### Why the Local Build is Faster

The optimized image achieves these improvements through **build-time file permissions**:

1. **Startup Time**: The original image sets permissions for ~15,000 files at runtime using `find`/`chmod`/`chown`. This takes 40-60 seconds. The optimized image sets permissions during `docker build`, so startup only handles files that change during setup.

2. **Memory Usage**: Runtime file scanning causes the Linux page cache to load all file metadata (~1.5 GB of cached data). By moving this to build time, the page cache stays minimal at runtime.

3. **Performance**: Both images perform identically under load since the optimizations only affect startup, not runtime execution.

For technical details, see the [OpenEMR 7.0.5 README](../../docker/openemr/7.0.5/README.md#performance-optimizations).

## Understanding Results

### Output Files

The benchmark generates several files in the `results/` directory:

1. **`benchmark_YYYYMMDD_HHMMSS.txt`** - Main results file with:
   - Startup times for both images
   - Performance metrics (requests/second, response times)
   - Resource utilization averages and peaks
   - Full Apache Bench output

2. **`Image_A_stats_YYYYMMDD_HHMMSS.txt`** - Detailed resource stats for Image A
3. **`Image_B_stats_YYYYMMDD_HHMMSS.txt`** - Detailed resource stats for Image B

### Key Metrics Explained

#### Startup Time
- **Lower is better**: Time in seconds for container to reach "healthy" status
- Includes database connection, OpenEMR initialization, and health check passing

#### Performance Metrics
- **Requests per second**: Higher is better - throughput under load
- **Time per request (mean)**: Lower is better - average response time in milliseconds
- **Failed requests**: Lower is better - number of requests that failed

#### Resource Utilization
- **Average CPU %**: Average CPU usage during load test
- **Average Memory (MB)**: Average memory usage during load test
- **Peak Memory (MB)**: Maximum memory usage observed

### Interpreting Results

**Example Output:**
```
Image_A_startup_time=15.0s
Image_B_startup_time=73.1s
startup_speedup=4.9x
Image_A_requests_per_second=114.88
Image_B_requests_per_second=117.18
Image_A_avg_memory_mb=92.8
Image_B_avg_memory_mb=304.2
```

**Interpretation:**
- Image A starts ~5x faster (15s vs 73s) due to build-time permissions
- Both handle similar requests per second (~115-117 req/s) - runtime performance is equivalent
- Image A uses ~70% less memory (93 MB vs 304 MB) due to reduced page cache

## How It Works

### Architecture

The benchmark uses Docker Compose to orchestrate:

1. **MySQL Database** - Shared database for both containers
2. **Image A Container** - Local build, exposed on port 8080
3. **Image B Container** - Docker Hub image, exposed on port 8081
4. **Load Generator** - Apache Bench container for generating load

### Benchmark Process

1. **Build Phase**: Builds Image A from local Dockerfile
2. **Startup Phase**: Starts both containers and measures time to healthy status
3. **Performance Phase**: Runs Apache Bench load tests against both containers
4. **Resource Phase**: Monitors CPU and memory usage during load testing
5. **Cleanup Phase**: Stops containers and generates reports

### Load Testing

The load test uses Apache Bench (`ab`) to simulate concurrent users:
- Sends requests to the OpenEMR login page
- Measures response times and throughput
- Reports success/failure rates

## Troubleshooting

### Container Won't Start

**Problem**: Containers fail to become healthy

**Solutions**:
- Check Docker logs: `docker compose -p container-benchmark logs`
- Verify MySQL is healthy: `docker compose -p container-benchmark ps mysql`
- Increase startup timeout in `benchmark.sh` if needed
- Check container status: `docker compose -p container-benchmark ps`

### MySQL Fails to Start - "No space left on device"

**Problem**: MySQL container exits with disk space error

**Symptoms**:
```
ERROR: mariadbd: Error writing file './ddl_recovery.log' (Errcode: 28 "No space left on device")
```

**Solutions**:
1. **Check disk space**: `df -h .`
2. **Clean up Docker**:
   ```bash
   docker system prune -a --volumes
   docker image prune -a
   ```
3. **Remove old containers**:
   ```bash
   docker container prune -f
   ```
4. **Check Docker disk usage**: `docker system df`
5. **Free up system disk space** if host is low on space

**Prevention**: The benchmark script now checks disk space before starting and warns if space is low.

### Container Exits Unexpectedly

**Problem**: Container starts then immediately exits

**Solutions**:
- Check logs: `docker compose -p container-benchmark logs <service-name>`
- Verify environment variables are set correctly
- Check for port conflicts
- Ensure MySQL is healthy before starting OpenEMR containers

### Port Conflicts

**Problem**: Port already in use error

**Solutions**:
- Change port mappings via environment variables (see Configuration section)
- Stop conflicting services: `docker ps` and stop containers using ports 8080/8081

### Out of Memory

**Problem**: Containers killed due to memory pressure

**Solutions**:
- Reduce `LOAD_TEST_CONCURRENT` and `LOAD_TEST_REQUESTS`
- Increase Docker memory limit
- Close other resource-intensive applications

### Network Issues

**Problem**: Cannot pull Image B from Docker Hub

**Solutions**:
- Check internet connectivity
- Verify Docker Hub access: `docker pull openemr/openemr:7.0.5`
- Use a different registry or local image for Image B

## Analysis Tools

The benchmarking suite includes several analysis tools to help interpret results:

### Summary Tool

View statistics across all benchmark runs:

```bash
./summary.sh
```

This displays:
- Min/Max/Average for all metrics across all runs
- Recent benchmark results
- Overall performance trends

### Compare Results

Compare Image A vs Image B from a benchmark run:

```bash
# Compare Image A vs Image B from most recent result
./compare_results.sh

# Compare Image A vs Image B from specific file
./compare_results.sh results/benchmark_20251125_200915.txt
```

This shows:
- Side-by-side comparison of Image A (Local Build) vs Image B (Docker Hub)
- Percentage differences for each metric
- Overall winner determination (which image performs better)

### CSV Export

Export all results to CSV for analysis in spreadsheet tools:

```bash
# Export all results
./export_to_csv.sh

# Export specific files
./export_to_csv.sh results/benchmark_20251125_200915.txt results/benchmark_20251125_200412.txt
```

The CSV file includes all metrics and can be opened in Excel, Google Sheets, or other analysis tools.

## Advanced Usage

### Comparing Multiple Versions

Create a wrapper script to test multiple versions:

```bash
#!/bin/bash
for version in 7.0.3 7.0.4 7.0.5; do
    export IMAGE_B_IMAGE="openemr/openemr:${version}"
    export RESULTS_DIR="./results/${version}"
    ./benchmark.sh
done
```

### Custom Load Patterns

Modify the `benchmark_performance()` function in `benchmark.sh` to:
- Test different endpoints
- Use different load patterns
- Add custom metrics

### Continuous Benchmarking

Integrate into CI/CD:

```yaml
# Example GitHub Actions step
- name: Run Benchmarks
  run: |
    cd utilities/container_benchmarking
    ./benchmark.sh
  env:
    IMAGE_A_CONTEXT: ./docker/openemr/7.0.5
    IMAGE_B_IMAGE: openemr/openemr:7.0.5
```

## Limitations

- **Short Duration**: Benchmarks run for minutes, not hours. Results represent short-term performance.
- **Single Load Pattern**: Uses fixed concurrent requests. Real-world usage may vary.
- **Local Environment**: Results depend on host system resources and may not reflect production.

## Contributing

To improve the benchmarking utility:

1. Keep it simple - avoid unnecessary complexity
2. Maintain clear comments and documentation
3. Ensure results are reproducible
4. Test with different image combinations

## See Also

- [OpenEMR Docker Documentation](../../docker/openemr/README.md)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Apache Bench Documentation](https://httpd.apache.org/docs/2.4/programs/ab.html)

