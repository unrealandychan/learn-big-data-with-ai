# Apache Airflow: Orchestration and Scheduling

## Learning Outcomes
- Understand DAG structure and task dependencies
- Design scalable data pipelines
- Implement error handling and retry logic
- Monitor and debug failing pipelines
- Deploy Airflow in production

**Estimated Time:** 2.5 hours  
**Prerequisites:** Governance Module 1 (dbt fundamentals)

## DAG Fundamentals

A DAG (Directed Acyclic Graph) defines workflow as code:

```python
# dags/data_warehouse_pipeline.py
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.operators.dummy import DummyOperator
from airflow.utils.dates import days_ago
from datetime import datetime, timedelta

default_args = {
    'owner': 'analytics',
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'email': 'analytics@company.com',
    'email_on_failure': True,
}

dag = DAG(
    'daily_warehouse_load',
    default_args=default_args,
    description='Daily extract, transform, load workflow',
    schedule_interval='0 2 * * *',  # 2 AM daily
    start_date=days_ago(1),
    catchup=False,
    tags=['warehouse', 'daily'],
)

# Tasks
start = DummyOperator(task_id='start', dag=dag)

extract_data = BashOperator(
    task_id='extract_raw_data',
    bash_command='python /jobs/extract.py',
    dag=dag,
)

load_staging = BashOperator(
    task_id='load_staging_tables',
    bash_command='cd /dbt/project && dbt run --select staging',
    dag=dag,
)

run_transformations = BashOperator(
    task_id='run_dbt_models',
    bash_command='cd /dbt/project && dbt run --select tag:prod',
    dag=dag,
)

run_tests = BashOperator(
    task_id='run_data_quality_tests',
    bash_command='cd /dbt/project && dbt test',
    dag=dag,
    trigger_rule='all_done',  # Run even if previous fails
)

notify_success = PythonOperator(
    task_id='notify_on_success',
    python_callable=lambda context: print("Pipeline successful!"),
    dag=dag,
)

# Define dependencies
start >> extract_data >> load_staging >> run_transformations >> run_tests >> notify_success
```

## Operators and Executors

```python
# Different operators for different workloads
from airflow.operators.postgres_operator import PostgresOperator
from airflow.operators.s3_operator import S3DeleteObjectsOperator
from airflow.operators.kubernetes_pod_operator import KubernetesPodOperator

# SQL execution
run_sql = PostgresOperator(
    task_id='execute_incremental_load',
    postgres_conn_id='warehouse',
    sql='sql/incremental_load.sql',
    dag=dag,
)

# Clean up S3
cleanup = S3DeleteObjectsOperator(
    task_id='cleanup_temp_s3_files',
    bucket='my-bucket',
    keys=['temp/staging/*'],
    aws_conn_id='aws_default',
    dag=dag,
)

# Run in Kubernetes
spark_job = KubernetesPodOperator(
    task_id='spark_transform',
    namespace='airflow',
    image='spark:3.2.0',
    cmds=['spark-submit', '--class', 'com.example.Transform', '/app/job.jar'],
    dag=dag,
)
```

## Task Dependencies and Branching

```python
from airflow.operators.branch import BranchPythonOperator

def check_file_exists(**context):
    """Decide which branch based on condition"""
    import os
    if os.path.exists('/data/daily_extract.csv'):
        return 'load_incremental'
    else:
        return 'load_full'

branch = BranchPythonOperator(
    task_id='check_load_type',
    python_callable=check_file_exists,
    dag=dag,
)

load_incremental = BashOperator(
    task_id='load_incremental',
    bash_command='python /jobs/incremental_load.py',
    dag=dag,
)

load_full = BashOperator(
    task_id='load_full',
    bash_command='python /jobs/full_load.py',
    dag=dag,
)

end = DummyOperator(task_id='end', trigger_rule='none_failed', dag=dag)

branch >> [load_incremental, load_full] >> end
```

## Error Handling and Retry Logic

```python
# Per-task retry configuration
extract_with_retry = BashOperator(
    task_id='extract_with_retry',
    bash_command='python /jobs/extract.py',
    retries=3,
    retry_delay=timedelta(minutes=10),
    retry_exponential_backoff=True,  # Exponential backoff: 10s, 20s, 40s
    max_retry_delay=timedelta(minutes=30),
    dag=dag,
)

# Trigger rules - when to run task
always_run = BashOperator(
    task_id='cleanup',
    bash_command='rm -rf /tmp/*',
    trigger_rule='all_done',  # Run regardless of upstream success/fail
    dag=dag,
)

fail_if_any_upstream_failed = BashOperator(
    task_id='critical_check',
    bash_command='python /jobs/validate.py',
    trigger_rule='all_success',  # Only run if all upstream succeeded
    dag=dag,
)
```

## Monitoring Pipeline Execution

```python
from airflow.models import Variable
from airflow.exceptions import AirflowException

def check_row_count(**context):
    """Custom function to validate output"""
    from sqlalchemy import create_engine
    
    engine = create_engine('postgresql://user:password@host/warehouse')
    with engine.connect() as conn:
        result = conn.execute("SELECT COUNT(*) FROM staging_orders")
        count = result.scalar()
        
        min_threshold = Variable.get('min_order_count', default_var=1000)
        if count < int(min_threshold):
            raise AirflowException(f'Row count {count} below threshold {min_threshold}')
        
        # Push to XCom for downstream tasks
        context['task_instance'].xcom_push(key='row_count', value=count)

validate = PythonOperator(
    task_id='validate_load',
    python_callable=check_row_count,
    dag=dag,
)

def use_xcom_value(**context):
    """Use value pushed by upstream task"""
    ti = context['task_instance']
    row_count = ti.xcom_pull(task_ids='validate_load', key='row_count')
    print(f"Previous task processed {row_count} rows")

downstream = PythonOperator(
    task_id='process_results',
    python_callable=use_xcom_value,
    dag=dag,
)

validate >> downstream
```

## Production Deployment

```yaml
# docker-compose.yml for local Airflow
version: '3'
services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow

  airflow:
    image: apache/airflow:2.0.0
    depends_on:
      - postgres
    environment:
      AIRFLOW__CORE__DAGS_FOLDER: /dags
      AIRFLOW__CORE__LOAD_EXAMPLES: 'False'
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql://airflow:airflow@postgres/airflow
    volumes:
      - ./dags:/dags
      - ./logs:/airflow/logs

  webserver:
    image: apache/airflow:2.0.0
    depends_on:
      - postgres
    ports:
      - "8080:8080"
    command: webserver
```

## Key Concepts

- **DAG:** Directed acyclic graph of tasks and dependencies
- **Operator:** Task type (BashOperator, PythonOperator, PostgresOperator, etc.)
- **XCom:** Cross-communication between tasks via shared variables
- **Trigger Rules:** When to execute task based on upstream status
- **Executor:** Orchestrator for task execution (Local, Kubernetes, Celery)

## Hands-On Lab

### Part 1: Basic DAG Creation
1. Create simple 3-task DAG
2. Define dependencies
3. Run DAG locally
4. Monitor execution via Web UI

### Part 2: Error Handling
1. Add retry logic with exponential backoff
2. Implement branching based on condition
3. Trigger cleanup tasks on failure
4. Use XCom for inter-task communication

### Part 3: Production Setup
1. Deploy multi-node Airflow (K8s executor)
2. Add alerting for pipeline failures
3. Implement SLA monitoring
4. Version control DAGs

*See Part 2 of course for complete lab walkthrough*

*Last Updated: March 2026*
