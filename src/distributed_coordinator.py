"""
Distributed Test Coordinator
Manages parallel test execution across multiple AWS instances
"""

import asyncio
import json
import logging
import time
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
import boto3
from botocore.exceptions import ClientError, NoCredentialsError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class TestJob:
    """Represents a test job to be processed"""
    id: str
    code: str
    language: str
    test_type: str = "unit"  # unit, integration, mutation
    priority: int = 1
    retry_count: int = 0
    max_retries: int = 3
    created_at: str = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc).isoformat()

@dataclass
class TestResult:
    """Represents the result of a test job"""
    job_id: str
    success: bool
    tests_generated: int
    tests_passed: int
    tests_failed: int
    coverage_percentage: float
    execution_time_ms: int
    error_message: Optional[str] = None
    generated_tests: Optional[str] = None
    completed_at: str = None
    
    def __post_init__(self):
        if self.completed_at is None:
            self.completed_at = datetime.now(timezone.utc).isoformat()

class DistributedTestCoordinator:
    """Coordinates distributed test execution across AWS instances"""
    
    def __init__(self, 
                 queue_url: str, 
                 result_bucket: str, 
                 region: str = 'us-east-1',
                 max_concurrent_jobs: int = 10):
        """
        Initialize the distributed test coordinator
        
        Args:
            queue_url: SQS queue URL for job distribution
            result_bucket: S3 bucket for storing test results
            region: AWS region
            max_concurrent_jobs: Maximum concurrent jobs per instance
        """
        self.queue_url = queue_url
        self.result_bucket = result_bucket
        self.region = region
        self.max_concurrent_jobs = max_concurrent_jobs
        
        # Initialize AWS clients
        try:
            self.sqs = boto3.client('sqs', region_name=region)
            self.s3 = boto3.client('s3', region_name=region)
            self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        except NoCredentialsError:
            logger.error("AWS credentials not found. Please configure AWS CLI.")
            raise
        
        # Job tracking
        self.active_jobs: Dict[str, TestJob] = {}
        self.completed_jobs: Dict[str, TestResult] = {}
        
        logger.info(f"Initialized DistributedTestCoordinator for region {region}")
    
    async def submit_test_job(self, job: TestJob) -> str:
        """
        Submit a test job to the distributed queue
        
        Args:
            job: TestJob instance to submit
            
        Returns:
            Message ID from SQS
        """
        try:
            message_body = json.dumps(asdict(job))
            
            response = self.sqs.send_message(
                QueueUrl=self.queue_url,
                MessageBody=message_body,
                MessageAttributes={
                    'Priority': {
                        'StringValue': str(job.priority),
                        'DataType': 'Number'
                    },
                    'Language': {
                        'StringValue': job.language,
                        'DataType': 'String'
                    },
                    'TestType': {
                        'StringValue': job.test_type,
                        'DataType': 'String'
                    }
                }
            )
            
            message_id = response['MessageId']
            self.active_jobs[job.id] = job
            
            logger.info(f"Submitted job {job.id} to queue with message ID {message_id}")
            
            # Send CloudWatch metric
            await self._send_metric('JobsSubmitted', 1)
            
            return message_id
            
        except ClientError as e:
            logger.error(f"Failed to submit job {job.id}: {e}")
            raise
    
    async def submit_batch_jobs(self, jobs: List[TestJob]) -> List[str]:
        """
        Submit multiple test jobs in batch
        
        Args:
            jobs: List of TestJob instances
            
        Returns:
            List of message IDs
        """
        message_ids = []
        
        # Process in batches of 10 (SQS limit)
        batch_size = 10
        for i in range(0, len(jobs), batch_size):
            batch = jobs[i:i + batch_size]
            
            entries = []
            for job in batch:
                entries.append({
                    'Id': job.id,
                    'MessageBody': json.dumps(asdict(job)),
                    'MessageAttributes': {
                        'Priority': {
                            'StringValue': str(job.priority),
                            'DataType': 'Number'
                        },
                        'Language': {
                            'StringValue': job.language,
                            'DataType': 'String'
                        }
                    }
                })
            
            try:
                response = self.sqs.send_message_batch(
                    QueueUrl=self.queue_url,
                    Entries=entries
                )
                
                # Track successful submissions
                for success in response.get('Successful', []):
                    job_id = success['Id']
                    message_id = success['MessageId']
                    message_ids.append(message_id)
                    
                    # Find the job and add to active tracking
                    job = next(j for j in batch if j.id == job_id)
                    self.active_jobs[job_id] = job
                
                # Log failed submissions
                for failure in response.get('Failed', []):
                    logger.error(f"Failed to submit job {failure['Id']}: {failure['Message']}")
                
                logger.info(f"Submitted batch of {len(response.get('Successful', []))} jobs")
                
            except ClientError as e:
                logger.error(f"Failed to submit job batch: {e}")
                raise
        
        await self._send_metric('BatchJobsSubmitted', len(message_ids))
        return message_ids
    
    async def process_test_jobs(self, max_concurrent: int = None):
        """
        Process test jobs from the queue with concurrency control
        
        Args:
            max_concurrent: Override default max concurrent jobs
        """
        if max_concurrent is None:
            max_concurrent = self.max_concurrent_jobs
        
        semaphore = asyncio.Semaphore(max_concurrent)
        logger.info(f"Starting job processing with max concurrency: {max_concurrent}")
        
        while True:
            try:
                # Receive messages from queue
                response = self.sqs.receive_message(
                    QueueUrl=self.queue_url,
                    MaxNumberOfMessages=10,
                    WaitTimeSeconds=20,  # Long polling
                    MessageAttributeNames=['All']
                )
                
                messages = response.get('Messages', [])
                if not messages:
                    logger.debug("No messages received, continuing to poll...")
                    continue
                
                logger.info(f"Received {len(messages)} messages from queue")
                
                # Process messages concurrently
                tasks = []
                for message in messages:
                    task = asyncio.create_task(
                        self._process_single_job(message, semaphore)
                    )
                    tasks.append(task)
                
                # Wait for all tasks to complete
                results = await asyncio.gather(*tasks, return_exceptions=True)
                
                # Log any exceptions
                for i, result in enumerate(results):
                    if isinstance(result, Exception):
                        logger.error(f"Task {i} failed with exception: {result}")
                
            except KeyboardInterrupt:
                logger.info("Received interrupt signal, shutting down gracefully...")
                break
            except Exception as e:
                logger.error(f"Error in job processing loop: {e}")
                await asyncio.sleep(5)  # Brief pause before retrying
    
    async def _process_single_job(self, message: Dict, semaphore: asyncio.Semaphore):
        """
        Process a single test job
        
        Args:
            message: SQS message containing job data
            semaphore: Concurrency control semaphore
        """
        async with semaphore:
            receipt_handle = message['ReceiptHandle']
            
            try:
                # Parse job data
                job_data = json.loads(message['Body'])
                job = TestJob(**job_data)
                
                logger.info(f"Processing job {job.id} for {job.language}")
                
                start_time = time.time()
                
                # Generate tests using local LLM
                test_result = await self._generate_tests(job)
                
                execution_time = int((time.time() - start_time) * 1000)
                test_result.execution_time_ms = execution_time
                
                # Store results in S3
                await self._store_results(job.id, test_result)
                
                # Track completion
                self.completed_jobs[job.id] = test_result
                if job.id in self.active_jobs:
                    del self.active_jobs[job.id]
                
                # Delete message from queue (job completed successfully)
                self.sqs.delete_message(
                    QueueUrl=self.queue_url,
                    ReceiptHandle=receipt_handle
                )
                
                logger.info(f"Completed job {job.id} in {execution_time}ms")
                
                # Send success metrics
                await self._send_metric('JobsCompleted', 1)
                await self._send_metric('TestsGenerated', test_result.tests_generated)
                
            except Exception as e:
                logger.error(f"Error processing job: {e}")
                
                # Handle retry logic
                try:
                    job_data = json.loads(message['Body'])
                    job = TestJob(**job_data)
                    
                    if job.retry_count < job.max_retries:
                        # Increment retry count and requeue
                        job.retry_count += 1
                        await self.submit_test_job(job)
                        logger.info(f"Requeued job {job.id} (retry {job.retry_count}/{job.max_retries})")
                    else:
                        # Max retries exceeded, store failure result
                        failure_result = TestResult(
                            job_id=job.id,
                            success=False,
                            tests_generated=0,
                            tests_passed=0,
                            tests_failed=0,
                            coverage_percentage=0.0,
                            execution_time_ms=0,
                            error_message=str(e)
                        )
                        await self._store_results(job.id, failure_result)
                        logger.error(f"Job {job.id} failed after {job.max_retries} retries")
                        
                        await self._send_metric('JobsFailed', 1)
                    
                    # Delete the original message
                    self.sqs.delete_message(
                        QueueUrl=self.queue_url,
                        ReceiptHandle=receipt_handle
                    )
                    
                except Exception as retry_error:
                    logger.error(f"Error handling job retry: {retry_error}")
    
    async def _generate_tests(self, job: TestJob) -> TestResult:
        """
        Generate tests using the local LLM
        
        Args:
            job: TestJob to process
            
        Returns:
            TestResult with generated tests and metrics
        """
        # This would integrate with the existing test generation logic
        # For now, we'll simulate the process
        
        logger.info(f"Generating {job.test_type} tests for {job.language} code")
        
        # Simulate test generation (replace with actual LLM integration)
        await asyncio.sleep(2)  # Simulate processing time
        
        # Mock results (replace with actual test generation)
        generated_tests = f"""
// Generated {job.test_type} tests for {job.language}
describe('{job.id}', () => {{
    it('should pass basic functionality test', () => {{
        // Test implementation here
        expect(true).toBe(true);
    }});
    
    it('should handle edge cases', () => {{
        // Edge case test implementation
        expect(true).toBe(true);
    }});
}});
"""
        
        return TestResult(
            job_id=job.id,
            success=True,
            tests_generated=2,
            tests_passed=2,
            tests_failed=0,
            coverage_percentage=85.5,
            execution_time_ms=0,  # Will be set by caller
            generated_tests=generated_tests
        )
    
    async def _store_results(self, job_id: str, result: TestResult):
        """
        Store test results in S3
        
        Args:
            job_id: Unique job identifier
            result: TestResult to store
        """
        try:
            key = f"test-results/{datetime.now().strftime('%Y/%m/%d')}/{job_id}.json"
            
            result_data = {
                'result': asdict(result),
                'metadata': {
                    'stored_at': datetime.now(timezone.utc).isoformat(),
                    'coordinator_version': '1.0.0'
                }
            }
            
            self.s3.put_object(
                Bucket=self.result_bucket,
                Key=key,
                Body=json.dumps(result_data, indent=2),
                ContentType='application/json',
                Metadata={
                    'job-id': job_id,
                    'success': str(result.success),
                    'tests-generated': str(result.tests_generated)
                }
            )
            
            logger.info(f"Stored results for job {job_id} at s3://{self.result_bucket}/{key}")
            
        except ClientError as e:
            logger.error(f"Failed to store results for job {job_id}: {e}")
            raise
    
    async def _send_metric(self, metric_name: str, value: float, unit: str = 'Count'):
        """
        Send custom metric to CloudWatch
        
        Args:
            metric_name: Name of the metric
            value: Metric value
            unit: Metric unit
        """
        try:
            self.cloudwatch.put_metric_data(
                Namespace='AI-Testing-Agent/Distributed',
                MetricData=[
                    {
                        'MetricName': metric_name,
                        'Value': value,
                        'Unit': unit,
                        'Timestamp': datetime.now(timezone.utc)
                    }
                ]
            )
        except ClientError as e:
            logger.warning(f"Failed to send metric {metric_name}: {e}")
    
    async def get_job_status(self, job_id: str) -> Dict[str, Any]:
        """
        Get the status of a specific job
        
        Args:
            job_id: Job identifier
            
        Returns:
            Job status information
        """
        if job_id in self.completed_jobs:
            result = self.completed_jobs[job_id]
            return {
                'status': 'completed',
                'success': result.success,
                'result': asdict(result)
            }
        elif job_id in self.active_jobs:
            job = self.active_jobs[job_id]
            return {
                'status': 'processing',
                'job': asdict(job),
                'submitted_at': job.created_at
            }
        else:
            return {
                'status': 'not_found',
                'message': f'Job {job_id} not found'
            }
    
    async def get_queue_stats(self) -> Dict[str, Any]:
        """
        Get queue statistics
        
        Returns:
            Queue statistics including message counts
        """
        try:
            response = self.sqs.get_queue_attributes(
                QueueUrl=self.queue_url,
                AttributeNames=[
                    'ApproximateNumberOfMessages',
                    'ApproximateNumberOfMessagesNotVisible',
                    'ApproximateNumberOfMessagesDelayed'
                ]
            )
            
            attributes = response['Attributes']
            
            return {
                'messages_available': int(attributes.get('ApproximateNumberOfMessages', 0)),
                'messages_in_flight': int(attributes.get('ApproximateNumberOfMessagesNotVisible', 0)),
                'messages_delayed': int(attributes.get('ApproximateNumberOfMessagesDelayed', 0)),
                'active_jobs': len(self.active_jobs),
                'completed_jobs': len(self.completed_jobs)
            }
            
        except ClientError as e:
            logger.error(f"Failed to get queue stats: {e}")
            return {'error': str(e)}

# CLI interface for testing
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Distributed Test Coordinator')
    parser.add_argument('--queue-url', required=True, help='SQS queue URL')
    parser.add_argument('--bucket', required=True, help='S3 results bucket')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--action', choices=['process', 'submit', 'status'], 
                       default='process', help='Action to perform')
    parser.add_argument('--job-id', help='Job ID for status check')
    parser.add_argument('--code', help='Code to test (for submit action)')
    parser.add_argument('--language', help='Programming language (for submit action)')
    
    args = parser.parse_args()
    
    coordinator = DistributedTestCoordinator(
        queue_url=args.queue_url,
        result_bucket=args.bucket,
        region=args.region
    )
    
    async def main():
        if args.action == 'process':
            await coordinator.process_test_jobs()
        elif args.action == 'submit' and args.code and args.language:
            job = TestJob(
                id=f"test-{int(time.time())}",
                code=args.code,
                language=args.language
            )
            message_id = await coordinator.submit_test_job(job)
            print(f"Submitted job {job.id} with message ID {message_id}")
        elif args.action == 'status':
            if args.job_id:
                status = await coordinator.get_job_status(args.job_id)
                print(json.dumps(status, indent=2))
            else:
                stats = await coordinator.get_queue_stats()
                print(json.dumps(stats, indent=2))
    
    asyncio.run(main()) 