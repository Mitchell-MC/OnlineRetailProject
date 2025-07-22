#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
DAG_ID="ecommerce_daily_etl_sdk"
CONF_FILE=""
DRY_RUN=false
FORCE=false
WAIT_FOR_COMPLETION=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --dag-id DAG_ID        DAG ID to run (default: ecommerce_daily_etl_sdk)"
    echo "  -c, --conf FILE            Configuration file for the DAG"
    echo "  -n, --dry-run              Show what would be executed without running"
    echo "  -f, --force                Force run even if DAG is paused"
    echo "  -w, --wait                 Wait for DAG completion and show status"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run default DAG"
    echo "  $0 -d my_custom_dag                   # Run specific DAG"
    echo "  $0 -d my_dag -c config.json          # Run DAG with config"
    echo "  $0 -d my_dag -n                       # Dry run"
    echo "  $0 -d my_dag -w                       # Run and wait for completion"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dag-id)
            DAG_ID="$2"
            shift 2
            ;;
        -c|--conf)
            CONF_FILE="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -w|--wait)
            WAIT_FOR_COMPLETION=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if we're in the right directory
if [ ! -f "docker-compose.yaml" ]; then
    print_error "docker-compose.yaml not found. Please run this script from the airflow-project directory."
    exit 1
fi

# Check if Airflow services are running
print_status "Checking if Airflow services are running..."
if ! docker compose ps | grep -q "Up"; then
    print_error "Airflow services are not running. Please start them first:"
    echo "  docker compose up -d"
    exit 1
fi

# Wait for Airflow webserver to be ready
print_status "Waiting for Airflow webserver to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        print_success "Airflow webserver is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "Airflow webserver is not responding after 30 seconds"
        exit 1
    fi
    sleep 2
done

# Check if DAG exists
print_status "Checking if DAG '$DAG_ID' exists..."
if ! docker compose exec webserver airflow dags list | grep -q "$DAG_ID"; then
    print_error "DAG '$DAG_ID' not found. Available DAGs:"
    docker compose exec webserver airflow dags list
    exit 1
fi

# Check DAG status
print_status "Checking DAG status..."
DAG_STATUS=$(docker compose exec webserver airflow dags state "$DAG_ID" 2>/dev/null || echo "unknown")

if [ "$DAG_STATUS" = "paused" ] && [ "$FORCE" = false ]; then
    print_warning "DAG '$DAG_ID' is paused. Use -f to force run."
    echo "To unpause the DAG: docker compose exec webserver airflow dags unpause '$DAG_ID'"
    exit 1
fi

# Build the trigger command
TRIGGER_CMD="docker compose exec webserver airflow dags trigger '$DAG_ID'"

if [ -n "$CONF_FILE" ]; then
    if [ ! -f "$CONF_FILE" ]; then
        print_error "Configuration file '$CONF_FILE' not found"
        exit 1
    fi
    TRIGGER_CMD="$TRIGGER_CMD --conf '$CONF_FILE'"
fi

# Dry run
if [ "$DRY_RUN" = true ]; then
    print_status "DRY RUN - Would execute:"
    echo "$TRIGGER_CMD"
    exit 0
fi

# Trigger the DAG
print_status "Triggering DAG '$DAG_ID'..."
RUN_ID=$(eval $TRIGGER_CMD 2>/dev/null | grep -o "run_id: [^[:space:]]*" | cut -d' ' -f2)

if [ -z "$RUN_ID" ]; then
    print_error "Failed to trigger DAG. Check the logs:"
    echo "docker compose logs webserver"
    exit 1
fi

print_success "DAG '$DAG_ID' triggered successfully with run_id: $RUN_ID"

# Wait for completion if requested
if [ "$WAIT_FOR_COMPLETION" = true ]; then
    print_status "Waiting for DAG completion..."
    
    while true; do
        DAG_STATE=$(docker compose exec webserver airflow dags state "$DAG_ID" "$RUN_ID" 2>/dev/null || echo "unknown")
        
        case $DAG_STATE in
            "success")
                print_success "DAG completed successfully!"
                break
                ;;
            "failed")
                print_error "DAG failed!"
                echo "Check the logs: docker compose logs scheduler"
                break
                ;;
            "running"|"queued"|"scheduled")
                print_status "DAG is still running (state: $DAG_STATE). Waiting..."
                sleep 10
                ;;
            *)
                print_warning "Unknown DAG state: $DAG_STATE"
                sleep 10
                ;;
        esac
    done
fi

# Show DAG information
echo ""
print_status "DAG Information:"
echo "  DAG ID: $DAG_ID"
echo "  Run ID: $RUN_ID"
echo "  Current State: $(docker compose exec webserver airflow dags state "$DAG_ID" "$RUN_ID" 2>/dev/null || echo "unknown")"
echo ""
echo "Useful commands:"
echo "  View DAG details: docker compose exec webserver airflow dags show '$DAG_ID'"
echo "  View task instances: docker compose exec webserver airflow tasks list '$DAG_ID' '$RUN_ID'"
echo "  View logs: docker compose logs scheduler"
echo "  Access Airflow UI: http://localhost:8080" 