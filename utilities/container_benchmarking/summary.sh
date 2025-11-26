#!/usr/bin/env bash
# ============================================================================
# Benchmark Results Summary Tool
# ============================================================================
# Provides a summary of all benchmark results with statistics
# Usage: ./summary.sh
# ============================================================================

set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-./results}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_section() {
    echo ""
    echo "============================================================================"
    echo "$*"
    echo "============================================================================"
}

# Extract metric from result file
extract_metric() {
    local file="${1}"
    local metric="${2}"
    grep "^${metric}=" "${file}" | cut -d'=' -f2 | sed 's/s$//' | sed 's/ms$//' || echo ""
}

# Calculate statistics
calculate_stats() {
    local values=("$@")
    local count=${#values[@]}
    
    if [[ "${count}" -eq 0 ]]; then
        echo "0,0,0,0"
        return
    fi
    
    # Filter out empty values and convert to numbers
    local valid_values=()
    for val in "${values[@]}"; do
        if [[ -n "${val}" ]] && [[ "${val}" != "0" ]] && [[ "${val}" != "N/A" ]]; then
            valid_values+=("${val}")
        fi
    done
    
    if [[ ${#valid_values[@]} -eq 0 ]]; then
        echo "0,0,0,0"
        return
    fi
    
    # Calculate min, max, avg using Python
    local result
    result=$(python3 -c "
import sys
try:
    values = [float(v) for v in sys.argv[1:] if v and v != '0' and v != 'N/A' and float(v) > 0]
    if not values:
        print('0,0,0,0')
    else:
        print(f'{min(values)},{max(values)},{sum(values)/len(values):.2f},{len(values)}')
except:
    print('0,0,0,0')
" "${valid_values[@]}" 2>/dev/null || echo "0,0,0,0")
    
    echo "${result}"
}

# Main function
main() {
    log_section "Benchmark Results Summary"
    
    # Find all result files using while read loop for portability
    local files=()
    while IFS= read -r file; do
        files+=("${file}")
    done < <(find "${RESULTS_DIR}" -name "benchmark_*.txt" -type f 2>/dev/null | sort || true)
    
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No benchmark results found in ${RESULTS_DIR}"
        exit 1
    fi
    
    echo "Found ${#files[@]} benchmark result(s)"
    echo ""
    
    # Collect metrics
    local startup_a_values=() startup_b_values=()
    local rps_a_values=() rps_b_values=()
    local time_a_values=() time_b_values=()
    local cpu_a_values=() cpu_b_values=()
    local mem_a_values=() mem_b_values=()
    
    for file in "${files[@]}"; do
        startup_a_values+=("$(extract_metric "${file}" "Image_A_startup_time")")
        startup_b_values+=("$(extract_metric "${file}" "Image_B_startup_time")")
        rps_a_values+=("$(extract_metric "${file}" "Image_A_requests_per_second")")
        rps_b_values+=("$(extract_metric "${file}" "Image_B_requests_per_second")")
        time_a_values+=("$(extract_metric "${file}" "Image_A_time_per_request_ms")")
        time_b_values+=("$(extract_metric "${file}" "Image_B_time_per_request_ms")")
        cpu_a_values+=("$(extract_metric "${file}" "Image_A_avg_cpu_percent")")
        cpu_b_values+=("$(extract_metric "${file}" "Image_B_avg_cpu_percent")")
        mem_a_values+=("$(extract_metric "${file}" "Image_A_avg_memory_mb")")
        mem_b_values+=("$(extract_metric "${file}" "Image_B_avg_memory_mb")")
    done
    
    # Calculate statistics
    local startup_a_stats startup_b_stats
    startup_a_stats=$(calculate_stats "${startup_a_values[@]}")
    startup_b_stats=$(calculate_stats "${startup_b_values[@]}")
    
    local rps_a_stats rps_b_stats
    rps_a_stats=$(calculate_stats "${rps_a_values[@]}")
    rps_b_stats=$(calculate_stats "${rps_b_values[@]}")
    
    local time_a_stats time_b_stats
    time_a_stats=$(calculate_stats "${time_a_values[@]}")
    time_b_stats=$(calculate_stats "${time_b_values[@]}")
    
    local cpu_a_stats cpu_b_stats
    cpu_a_stats=$(calculate_stats "${cpu_a_values[@]}")
    cpu_b_stats=$(calculate_stats "${cpu_b_values[@]}")
    
    local mem_a_stats mem_b_stats
    mem_a_stats=$(calculate_stats "${mem_a_values[@]}")
    mem_b_stats=$(calculate_stats "${mem_b_values[@]}")
    
    # Display summary
    log_section "Statistics Summary"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "METRIC                    | IMAGE A (Local)              | IMAGE B (Docker Hub)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Startup Time
    local a_min a_max a_avg
    IFS=',' read -r a_min a_max a_avg _ <<< "${startup_a_stats}"
    local b_min b_max b_avg
    IFS=',' read -r b_min b_max b_avg _ <<< "${startup_b_stats}"
    printf "Startup Time (s)          | Min: %-6.2f Avg: %-6.2f Max: %-6.2f | Min: %-6.2f Avg: %-6.2f Max: %-6.2f\n" \
        "${a_min}" "${a_avg}" "${a_max}" "${b_min}" "${b_avg}" "${b_max}"
    
    # Requests per Second
    IFS=',' read -r a_min a_max a_avg _ <<< "${rps_a_stats}"
    IFS=',' read -r b_min b_max b_avg _ <<< "${rps_b_stats}"
    printf "Requests/Second           | Min: %-6.2f Avg: %-6.2f Max: %-6.2f | Min: %-6.2f Avg: %-6.2f Max: %-6.2f\n" \
        "${a_min}" "${a_avg}" "${a_max}" "${b_min}" "${b_avg}" "${b_max}"
    
    # Response Time
    IFS=',' read -r a_min a_max a_avg _ <<< "${time_a_stats}"
    IFS=',' read -r b_min b_max b_avg _ <<< "${time_b_stats}"
    printf "Avg Response Time (ms)    | Min: %-6.2f Avg: %-6.2f Max: %-6.2f | Min: %-6.2f Avg: %-6.2f Max: %-6.2f\n" \
        "${a_min}" "${a_avg}" "${a_max}" "${b_min}" "${b_avg}" "${b_max}"
    
    # CPU Usage
    IFS=',' read -r a_min a_max a_avg _ <<< "${cpu_a_stats}"
    IFS=',' read -r b_min b_max b_avg _ <<< "${cpu_b_stats}"
    printf "Avg CPU Usage (%%)         | Min: %-6.2f Avg: %-6.2f Max: %-6.2f | Min: %-6.2f Avg: %-6.2f Max: %-6.2f\n" \
        "${a_min}" "${a_avg}" "${a_max}" "${b_min}" "${b_avg}" "${b_max}"
    
    # Memory Usage
    IFS=',' read -r a_min a_max a_avg _ <<< "${mem_a_stats}"
    IFS=',' read -r b_min b_max b_avg _ <<< "${mem_b_stats}"
    printf "Avg Memory Usage (MB)     | Min: %-6.2f Avg: %-6.2f Max: %-6.2f | Min: %-6.2f Avg: %-6.2f Max: %-6.2f\n" \
        "${a_min}" "${a_avg}" "${a_max}" "${b_min}" "${b_avg}" "${b_max}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    log_section "Recent Results"
    
    # Show last 5 results using while read loop for portability
    local recent_files=()
    while IFS= read -r file; do
        recent_files+=("${file}")
    done < <(find "${RESULTS_DIR}" -name "benchmark_*.txt" -type f 2>/dev/null | sort -r | head -5 || true)
    
    for file in "${recent_files[@]}"; do
        local timestamp
        timestamp=$(basename "${file}" | sed 's/benchmark_//' | sed 's/\.txt$//')
        local startup_a startup_b
        startup_a=$(extract_metric "${file}" "Image_A_startup_time")
        startup_b=$(extract_metric "${file}" "Image_B_startup_time")
        local rps_a rps_b
        rps_a=$(extract_metric "${file}" "Image_A_requests_per_second")
        rps_b=$(extract_metric "${file}" "Image_B_requests_per_second")
        
        echo -e "${CYAN}${timestamp}${NC}:"
        echo "  Startup: A=${startup_a}s, B=${startup_b}s | RPS: A=${rps_a}, B=${rps_b}"
    done
    
    echo ""
    log_success "Summary complete!"
    log_info "Use './compare_results.sh' to compare specific results"
    log_info "Use './export_to_csv.sh' to export all results to CSV"
}

main "$@"
