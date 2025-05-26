"""
Parallel Test Executor
Manages different test execution strategies across distributed instances
"""

import asyncio
import logging
import time
from typing import List, Dict, Any, Optional, Callable
from dataclasses import dataclass
from enum import Enum
import concurrent.futures
from distributed_coordinator import TestJob, TestResult, DistributedTestCoordinator

logger = logging.getLogger(__name__)

class ExecutionStrategy(Enum):
    """Test execution strategies"""
    SEQUENTIAL = "sequential"
    PARALLEL_FILES = "parallel_files"
    PARALLEL_FUNCTIONS = "parallel_functions"
    HYBRID = "hybrid"
    LOAD_BALANCED = "load_balanced"

@dataclass
class ExecutionConfig:
    """Configuration for test execution"""
    strategy: ExecutionStrategy
    max_workers: int = 4
    timeout_seconds: int = 300
    retry_attempts: int = 3
    batch_size: int = 10
    priority_levels: List[int] = None
    
    def __post_init__(self):
        if self.priority_levels is None:
            self.priority_levels = [1, 2, 3]  # High, Medium, Low

@dataclass
class ExecutionResult:
    """Result of parallel execution"""
    total_jobs: int
    completed_jobs: int
    failed_jobs: int
    execution_time_ms: int
    average_job_time_ms: float
    throughput_jobs_per_second: float
    error_rate_percentage: float
    results: List[TestResult]

class ParallelTestExecutor:
    """Manages parallel test execution across distributed instances"""
    
    def __init__(self, coordinator: DistributedTestCoordinator, config: ExecutionConfig):
        """
        Initialize the parallel test executor
        
        Args:
            coordinator: DistributedTestCoordinator instance
            config: ExecutionConfig for this executor
        """
        self.coordinator = coordinator
        self.config = config
        self.active_executions: Dict[str, asyncio.Task] = {}
        
        logger.info(f"Initialized ParallelTestExecutor with strategy: {config.strategy}")
    
    async def execute_test_suite(self, 
                                jobs: List[TestJob], 
                                progress_callback: Optional[Callable] = None) -> ExecutionResult:
        """
        Execute a test suite using the configured strategy
        
        Args:
            jobs: List of TestJob instances to execute
            progress_callback: Optional callback for progress updates
            
        Returns:
            ExecutionResult with comprehensive metrics
        """
        start_time = time.time()
        
        logger.info(f"Starting execution of {len(jobs)} jobs using {self.config.strategy.value} strategy")
        
        # Choose execution strategy
        if self.config.strategy == ExecutionStrategy.SEQUENTIAL:
            results = await self._execute_sequential(jobs, progress_callback)
        elif self.config.strategy == ExecutionStrategy.PARALLEL_FILES:
            results = await self._execute_parallel_files(jobs, progress_callback)
        elif self.config.strategy == ExecutionStrategy.PARALLEL_FUNCTIONS:
            results = await self._execute_parallel_functions(jobs, progress_callback)
        elif self.config.strategy == ExecutionStrategy.HYBRID:
            results = await self._execute_hybrid(jobs, progress_callback)
        elif self.config.strategy == ExecutionStrategy.LOAD_BALANCED:
            results = await self._execute_load_balanced(jobs, progress_callback)
        else:
            raise ValueError(f"Unknown execution strategy: {self.config.strategy}")
        
        end_time = time.time()
        execution_time_ms = int((end_time - start_time) * 1000)
        
        # Calculate metrics
        completed_jobs = len([r for r in results if r.success])
        failed_jobs = len([r for r in results if not r.success])
        
        average_job_time = sum(r.execution_time_ms for r in results) / len(results) if results else 0
        throughput = len(results) / (execution_time_ms / 1000) if execution_time_ms > 0 else 0
        error_rate = (failed_jobs / len(results) * 100) if results else 0
        
        execution_result = ExecutionResult(
            total_jobs=len(jobs),
            completed_jobs=completed_jobs,
            failed_jobs=failed_jobs,
            execution_time_ms=execution_time_ms,
            average_job_time_ms=average_job_time,
            throughput_jobs_per_second=throughput,
            error_rate_percentage=error_rate,
            results=results
        )
        
        logger.info(f"Execution completed: {completed_jobs}/{len(jobs)} jobs successful, "
                   f"throughput: {throughput:.2f} jobs/sec, error rate: {error_rate:.1f}%")
        
        return execution_result
    
    async def _execute_sequential(self, 
                                 jobs: List[TestJob], 
                                 progress_callback: Optional[Callable] = None) -> List[TestResult]:
        """Execute jobs sequentially (one at a time)"""
        results = []
        
        for i, job in enumerate(jobs):
            logger.debug(f"Processing job {i+1}/{len(jobs)}: {job.id}")
            
            try:
                # Submit job and wait for completion
                message_id = await self.coordinator.submit_test_job(job)
                result = await self._wait_for_job_completion(job.id)
                results.append(result)
                
                if progress_callback:
                    await progress_callback(i + 1, len(jobs), result)
                    
            except Exception as e:
                logger.error(f"Failed to execute job {job.id}: {e}")
                # Create failure result
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
                results.append(failure_result)
        
        return results
    
    async def _execute_parallel_files(self, 
                                     jobs: List[TestJob], 
                                     progress_callback: Optional[Callable] = None) -> List[TestResult]:
        """Execute jobs in parallel batches (file-level parallelism)"""
        results = []
        
        # Process jobs in batches
        for batch_start in range(0, len(jobs), self.config.batch_size):
            batch_end = min(batch_start + self.config.batch_size, len(jobs))
            batch = jobs[batch_start:batch_end]
            
            logger.info(f"Processing batch {batch_start//self.config.batch_size + 1}: "
                       f"jobs {batch_start+1}-{batch_end}")
            
            # Submit all jobs in batch
            submission_tasks = []
            for job in batch:
                task = asyncio.create_task(self.coordinator.submit_test_job(job))
                submission_tasks.append(task)
            
            # Wait for all submissions
            message_ids = await asyncio.gather(*submission_tasks, return_exceptions=True)
            
            # Wait for all completions
            completion_tasks = []
            for job in batch:
                task = asyncio.create_task(self._wait_for_job_completion(job.id))
                completion_tasks.append(task)
            
            batch_results = await asyncio.gather(*completion_tasks, return_exceptions=True)
            
            # Process results
            for i, result in enumerate(batch_results):
                if isinstance(result, Exception):
                    logger.error(f"Job {batch[i].id} failed: {result}")
                    failure_result = TestResult(
                        job_id=batch[i].id,
                        success=False,
                        tests_generated=0,
                        tests_passed=0,
                        tests_failed=0,
                        coverage_percentage=0.0,
                        execution_time_ms=0,
                        error_message=str(result)
                    )
                    results.append(failure_result)
                else:
                    results.append(result)
            
            if progress_callback:
                await progress_callback(len(results), len(jobs), batch_results[-1] if batch_results else None)
        
        return results
    
    async def _execute_parallel_functions(self, 
                                         jobs: List[TestJob], 
                                         progress_callback: Optional[Callable] = None) -> List[TestResult]:
        """Execute jobs with function-level parallelism (fine-grained)"""
        semaphore = asyncio.Semaphore(self.config.max_workers)
        
        async def execute_single_job(job: TestJob) -> TestResult:
            async with semaphore:
                try:
                    message_id = await self.coordinator.submit_test_job(job)
                    result = await self._wait_for_job_completion(job.id)
                    return result
                except Exception as e:
                    logger.error(f"Failed to execute job {job.id}: {e}")
                    return TestResult(
                        job_id=job.id,
                        success=False,
                        tests_generated=0,
                        tests_passed=0,
                        tests_failed=0,
                        coverage_percentage=0.0,
                        execution_time_ms=0,
                        error_message=str(e)
                    )
        
        # Create tasks for all jobs
        tasks = [asyncio.create_task(execute_single_job(job)) for job in jobs]
        
        # Wait for completion with progress tracking
        results = []
        for i, task in enumerate(asyncio.as_completed(tasks)):
            result = await task
            results.append(result)
            
            if progress_callback:
                await progress_callback(i + 1, len(jobs), result)
        
        return results
    
    async def _execute_hybrid(self, 
                             jobs: List[TestJob], 
                             progress_callback: Optional[Callable] = None) -> List[TestResult]:
        """Execute jobs using hybrid strategy (priority-based)"""
        # Separate jobs by priority
        priority_groups = {}
        for job in jobs:
            priority = job.priority
            if priority not in priority_groups:
                priority_groups[priority] = []
            priority_groups[priority].append(job)
        
        results = []
        
        # Process high priority jobs first (sequential for reliability)
        if 1 in priority_groups:  # High priority
            logger.info(f"Processing {len(priority_groups[1])} high-priority jobs sequentially")
            high_priority_results = await self._execute_sequential(priority_groups[1])
            results.extend(high_priority_results)
        
        # Process medium priority jobs in parallel
        if 2 in priority_groups:  # Medium priority
            logger.info(f"Processing {len(priority_groups[2])} medium-priority jobs in parallel")
            medium_priority_results = await self._execute_parallel_files(priority_groups[2])
            results.extend(medium_priority_results)
        
        # Process low priority jobs with maximum parallelism
        if 3 in priority_groups:  # Low priority
            logger.info(f"Processing {len(priority_groups[3])} low-priority jobs with max parallelism")
            low_priority_results = await self._execute_parallel_functions(priority_groups[3])
            results.extend(low_priority_results)
        
        return results
    
    async def _execute_load_balanced(self, 
                                    jobs: List[TestJob], 
                                    progress_callback: Optional[Callable] = None) -> List[TestResult]:
        """Execute jobs with dynamic load balancing"""
        # Monitor queue stats and adjust strategy dynamically
        queue_stats = await self.coordinator.get_queue_stats()
        
        # Determine optimal strategy based on current load
        if queue_stats.get('messages_available', 0) > 50:
            # High queue load - use sequential to avoid overwhelming
            logger.info("High queue load detected, using sequential execution")
            return await self._execute_sequential(jobs, progress_callback)
        elif queue_stats.get('messages_in_flight', 0) < 10:
            # Low load - use maximum parallelism
            logger.info("Low queue load detected, using parallel functions execution")
            return await self._execute_parallel_functions(jobs, progress_callback)
        else:
            # Medium load - use parallel files
            logger.info("Medium queue load detected, using parallel files execution")
            return await self._execute_parallel_files(jobs, progress_callback)
    
    async def _wait_for_job_completion(self, job_id: str, timeout_seconds: int = None) -> TestResult:
        """
        Wait for a job to complete and return the result
        
        Args:
            job_id: Job identifier to wait for
            timeout_seconds: Optional timeout override
            
        Returns:
            TestResult when job completes
        """
        if timeout_seconds is None:
            timeout_seconds = self.config.timeout_seconds
        
        start_time = time.time()
        
        while time.time() - start_time < timeout_seconds:
            status = await self.coordinator.get_job_status(job_id)
            
            if status['status'] == 'completed':
                return TestResult(**status['result'])
            elif status['status'] == 'not_found':
                # Job might not be processed yet, continue waiting
                pass
            
            # Wait before checking again
            await asyncio.sleep(1)
        
        # Timeout reached
        raise TimeoutError(f"Job {job_id} did not complete within {timeout_seconds} seconds")
    
    async def cancel_execution(self, execution_id: str):
        """Cancel an active execution"""
        if execution_id in self.active_executions:
            task = self.active_executions[execution_id]
            task.cancel()
            del self.active_executions[execution_id]
            logger.info(f"Cancelled execution {execution_id}")
    
    async def get_execution_stats(self) -> Dict[str, Any]:
        """Get current execution statistics"""
        return {
            'active_executions': len(self.active_executions),
            'strategy': self.config.strategy.value,
            'max_workers': self.config.max_workers,
            'batch_size': self.config.batch_size,
            'timeout_seconds': self.config.timeout_seconds
        }

class TestSuiteBuilder:
    """Helper class for building test suites from code repositories"""
    
    @staticmethod
    def from_file_list(file_paths: List[str], 
                      language: str = "javascript",
                      test_type: str = "unit") -> List[TestJob]:
        """
        Create test jobs from a list of file paths
        
        Args:
            file_paths: List of file paths to create tests for
            language: Programming language
            test_type: Type of tests to generate
            
        Returns:
            List of TestJob instances
        """
        jobs = []
        
        for i, file_path in enumerate(file_paths):
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    code = f.read()
                
                job = TestJob(
                    id=f"file-{i}-{int(time.time())}",
                    code=code,
                    language=language,
                    test_type=test_type,
                    priority=1  # Default priority
                )
                jobs.append(job)
                
            except Exception as e:
                logger.warning(f"Failed to read file {file_path}: {e}")
        
        return jobs
    
    @staticmethod
    def from_git_diff(diff_content: str, 
                     language: str = "javascript",
                     test_type: str = "unit") -> List[TestJob]:
        """
        Create test jobs from git diff content
        
        Args:
            diff_content: Git diff content
            language: Programming language
            test_type: Type of tests to generate
            
        Returns:
            List of TestJob instances
        """
        # Parse diff and extract changed code sections
        # This is a simplified implementation
        jobs = []
        
        # Split diff into files
        files = diff_content.split('diff --git')
        
        for i, file_diff in enumerate(files[1:]):  # Skip first empty split
            if not file_diff.strip():
                continue
            
            # Extract added lines (simplified)
            added_lines = []
            for line in file_diff.split('\n'):
                if line.startswith('+') and not line.startswith('+++'):
                    added_lines.append(line[1:])  # Remove + prefix
            
            if added_lines:
                code = '\n'.join(added_lines)
                job = TestJob(
                    id=f"diff-{i}-{int(time.time())}",
                    code=code,
                    language=language,
                    test_type=test_type,
                    priority=2  # Medium priority for diffs
                )
                jobs.append(job)
        
        return jobs

# Example usage and testing
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Parallel Test Executor')
    parser.add_argument('--queue-url', required=True, help='SQS queue URL')
    parser.add_argument('--bucket', required=True, help='S3 results bucket')
    parser.add_argument('--strategy', choices=[s.value for s in ExecutionStrategy], 
                       default='parallel_files', help='Execution strategy')
    parser.add_argument('--max-workers', type=int, default=4, help='Maximum workers')
    parser.add_argument('--files', nargs='+', help='Files to generate tests for')
    
    args = parser.parse_args()
    
    async def main():
        # Initialize coordinator and executor
        coordinator = DistributedTestCoordinator(
            queue_url=args.queue_url,
            result_bucket=args.bucket
        )
        
        config = ExecutionConfig(
            strategy=ExecutionStrategy(args.strategy),
            max_workers=args.max_workers
        )
        
        executor = ParallelTestExecutor(coordinator, config)
        
        # Create test jobs from files
        if args.files:
            jobs = TestSuiteBuilder.from_file_list(args.files)
            
            # Progress callback
            async def progress_callback(completed: int, total: int, last_result: TestResult):
                print(f"Progress: {completed}/{total} ({completed/total*100:.1f}%)")
                if last_result:
                    print(f"Last job: {last_result.job_id} - Success: {last_result.success}")
            
            # Execute test suite
            result = await executor.execute_test_suite(jobs, progress_callback)
            
            print(f"\nExecution Summary:")
            print(f"Total jobs: {result.total_jobs}")
            print(f"Completed: {result.completed_jobs}")
            print(f"Failed: {result.failed_jobs}")
            print(f"Execution time: {result.execution_time_ms}ms")
            print(f"Throughput: {result.throughput_jobs_per_second:.2f} jobs/sec")
            print(f"Error rate: {result.error_rate_percentage:.1f}%")
        else:
            print("No files specified. Use --files to specify files to test.")
    
    asyncio.run(main()) 