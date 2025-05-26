"""
Error Distributor
Intelligent error classification and routing for distributed error fixing
"""

import asyncio
import json
import logging
import re
import time
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from enum import Enum
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

class ErrorType(Enum):
    """Types of errors that can be classified and routed"""
    TYPESCRIPT = "typescript"
    REACT = "react"
    TEST = "test"
    LINT = "lint"
    BUILD = "build"
    RUNTIME = "runtime"
    DEPENDENCY = "dependency"
    GENERAL = "general"

class ErrorSeverity(Enum):
    """Error severity levels for prioritization"""
    CRITICAL = 1  # Blocks compilation/build
    HIGH = 2      # Breaks functionality
    MEDIUM = 3    # Degrades experience
    LOW = 4       # Minor issues

@dataclass
class ErrorContext:
    """Context information for an error"""
    file_path: str
    line_number: Optional[int] = None
    column_number: Optional[int] = None
    function_name: Optional[str] = None
    class_name: Optional[str] = None
    surrounding_code: Optional[str] = None

@dataclass
class ErrorJob:
    """Represents an error fixing job to be distributed"""
    id: str
    error_type: ErrorType
    severity: ErrorSeverity
    message: str
    context: ErrorContext
    suggested_model: str
    priority_score: float
    retry_count: int = 0
    max_retries: int = 3
    created_at: str = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc).isoformat()

@dataclass
class ErrorFixResult:
    """Result of an error fixing attempt"""
    job_id: str
    success: bool
    fixed_code: Optional[str] = None
    explanation: Optional[str] = None
    confidence_score: float = 0.0
    execution_time_ms: int = 0
    model_used: str = ""
    error_message: Optional[str] = None
    completed_at: str = None
    
    def __post_init__(self):
        if self.completed_at is None:
            self.completed_at = datetime.now(timezone.utc).isoformat()

class ErrorClassifier:
    """Classifies errors and determines appropriate fixing strategies"""
    
    def __init__(self):
        self.error_patterns = {
            ErrorType.TYPESCRIPT: [
                r"TS\d+:",
                r"Type '.*' is not assignable to type",
                r"Property '.*' does not exist on type",
                r"Cannot find name '.*'",
                r"Expected \d+ arguments, but got \d+",
                r"Object is possibly 'null'",
                r"Object is possibly 'undefined'",
            ],
            ErrorType.REACT: [
                r"React Hook",
                r"Invalid hook call",
                r"Cannot read propert(y|ies) of undefined",
                r"Cannot read propert(y|ies) of null",
                r"JSX element .* has no corresponding closing tag",
                r"Expected an assignment or function call",
            ],
            ErrorType.TEST: [
                r"Test failed",
                r"expect\(.*\)\.to",
                r"AssertionError",
                r"ReferenceError.*describe",
                r"ReferenceError.*it",
                r"ReferenceError.*expect",
                r"vitest",
                r"jest",
            ],
            ErrorType.LINT: [
                r"eslint",
                r"Parsing error",
                r"'.*' is defined but never used",
                r"Missing semicolon",
                r"Unexpected token",
            ],
            ErrorType.BUILD: [
                r"Build failed",
                r"Module not found",
                r"Cannot resolve module",
                r"Compilation error",
                r"SyntaxError: Unexpected token",
            ],
            ErrorType.RUNTIME: [
                r"ReferenceError",
                r"TypeError",
                r"RangeError",
                r"SyntaxError",
                r"at runtime",
            ],
            ErrorType.DEPENDENCY: [
                r"npm ERR!",
                r"yarn error",
                r"Package .* not found",
                r"Module .* not found",
                r"Cannot find module",
            ]
        }
        
        self.severity_patterns = {
            ErrorSeverity.CRITICAL: [
                r"Build failed",
                r"Compilation error",
                r"SyntaxError",
                r"Cannot find module",
                r"TS\d+:",  # TypeScript errors are often critical
            ],
            ErrorSeverity.HIGH: [
                r"TypeError",
                r"ReferenceError",
                r"Test failed",
                r"Cannot read propert",
            ],
            ErrorSeverity.MEDIUM: [
                r"eslint",
                r"Warning",
                r"Deprecated",
            ],
            ErrorSeverity.LOW: [
                r"'.*' is defined but never used",
                r"Missing semicolon",
                r"Prefer const",
            ]
        }
        
        # Model recommendations based on error type and complexity
        self.model_recommendations = {
            ErrorType.TYPESCRIPT: {
                "simple": "deepseek-coder:1.3b",
                "complex": "deepseek-coder:6.7b",
                "advanced": "deepseek-coder:33b"
            },
            ErrorType.REACT: {
                "simple": "deepseek-coder:1.3b",
                "complex": "deepseek-coder:6.7b",
                "advanced": "deepseek-coder:33b"
            },
            ErrorType.TEST: {
                "simple": "deepseek-coder:1.3b",
                "complex": "deepseek-coder:6.7b",
                "advanced": "deepseek-coder:6.7b"
            },
            ErrorType.LINT: {
                "simple": "deepseek-coder:1.3b",
                "complex": "deepseek-coder:1.3b",
                "advanced": "deepseek-coder:6.7b"
            },
            ErrorType.BUILD: {
                "simple": "deepseek-coder:6.7b",
                "complex": "deepseek-coder:33b",
                "advanced": "deepseek-coder:33b"
            },
            ErrorType.RUNTIME: {
                "simple": "deepseek-coder:1.3b",
                "complex": "deepseek-coder:6.7b",
                "advanced": "deepseek-coder:33b"
            },
            ErrorType.DEPENDENCY: {
                "simple": "llama3.2:1b",
                "complex": "deepseek-coder:1.3b",
                "advanced": "deepseek-coder:6.7b"
            },
            ErrorType.GENERAL: {
                "simple": "llama3.2:1b",
                "complex": "deepseek-coder:1.3b",
                "advanced": "deepseek-coder:6.7b"
            }
        }
    
    def classify_error(self, error_message: str, context: ErrorContext) -> Tuple[ErrorType, ErrorSeverity]:
        """
        Classify an error message and context into type and severity
        
        Args:
            error_message: The error message to classify
            context: Additional context about the error
            
        Returns:
            Tuple of (ErrorType, ErrorSeverity)
        """
        error_type = self._classify_error_type(error_message, context)
        severity = self._classify_severity(error_message, context)
        
        return error_type, severity
    
    def _classify_error_type(self, error_message: str, context: ErrorContext) -> ErrorType:
        """Classify the type of error based on message and context"""
        # Check file extension for additional context
        file_ext = context.file_path.split('.')[-1].lower() if context.file_path else ""
        
        # TypeScript files get priority for TS classification
        if file_ext in ['ts', 'tsx'] and any(re.search(pattern, error_message, re.IGNORECASE) 
                                           for pattern in self.error_patterns[ErrorType.TYPESCRIPT]):
            return ErrorType.TYPESCRIPT
        
        # Test files get priority for test classification
        if ('test' in context.file_path.lower() or 'spec' in context.file_path.lower()) and \
           any(re.search(pattern, error_message, re.IGNORECASE) 
               for pattern in self.error_patterns[ErrorType.TEST]):
            return ErrorType.TEST
        
        # Check all patterns
        for error_type, patterns in self.error_patterns.items():
            if any(re.search(pattern, error_message, re.IGNORECASE) for pattern in patterns):
                return error_type
        
        return ErrorType.GENERAL
    
    def _classify_severity(self, error_message: str, context: ErrorContext) -> ErrorSeverity:
        """Classify the severity of an error"""
        for severity, patterns in self.severity_patterns.items():
            if any(re.search(pattern, error_message, re.IGNORECASE) for pattern in patterns):
                return severity
        
        return ErrorSeverity.MEDIUM  # Default severity
    
    def recommend_model(self, error_type: ErrorType, complexity: str = "simple") -> str:
        """
        Recommend the best model for fixing a specific error type
        
        Args:
            error_type: The type of error to fix
            complexity: Complexity level ("simple", "complex", "advanced")
            
        Returns:
            Recommended model name
        """
        return self.model_recommendations.get(error_type, {}).get(
            complexity, "deepseek-coder:1.3b"
        )
    
    def calculate_priority_score(self, error_type: ErrorType, severity: ErrorSeverity, 
                                context: ErrorContext) -> float:
        """
        Calculate a priority score for error fixing order
        
        Args:
            error_type: Type of the error
            severity: Severity of the error
            context: Error context
            
        Returns:
            Priority score (higher = more urgent)
        """
        base_score = 10.0 - severity.value  # Critical=9, High=8, Medium=7, Low=6
        
        # Boost priority for certain error types
        type_multipliers = {
            ErrorType.TYPESCRIPT: 1.2,
            ErrorType.BUILD: 1.3,
            ErrorType.REACT: 1.1,
            ErrorType.TEST: 1.0,
            ErrorType.LINT: 0.8,
            ErrorType.RUNTIME: 1.1,
            ErrorType.DEPENDENCY: 1.2,
            ErrorType.GENERAL: 0.9
        }
        
        score = base_score * type_multipliers.get(error_type, 1.0)
        
        # Boost priority for critical files
        if context.file_path:
            critical_paths = [
                'src/main', 'src/app', 'src/index', 
                'package.json', 'tsconfig.json', 'vite.config'
            ]
            if any(critical in context.file_path.lower() for critical in critical_paths):
                score *= 1.2
        
        return round(score, 2)

class ErrorDistributor:
    """Distributes error fixing jobs across multiple instances"""
    
    def __init__(self, 
                 error_queue_url: str, 
                 result_bucket: str,
                 region: str = 'us-east-1'):
        """
        Initialize the error distributor
        
        Args:
            error_queue_url: SQS queue URL for error jobs
            result_bucket: S3 bucket for storing fix results
            region: AWS region
        """
        self.error_queue_url = error_queue_url
        self.result_bucket = result_bucket
        self.region = region
        
        # Initialize AWS clients
        try:
            self.sqs = boto3.client('sqs', region_name=region)
            self.s3 = boto3.client('s3', region_name=region)
            self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        except Exception as e:
            logger.error(f"Failed to initialize AWS clients: {e}")
            raise
        
        self.classifier = ErrorClassifier()
        self.active_jobs: Dict[str, ErrorJob] = {}
        self.completed_jobs: Dict[str, ErrorFixResult] = {}
        
        logger.info(f"Initialized ErrorDistributor for region {region}")
    
    async def distribute_errors(self, errors: List[Dict[str, Any]]) -> List[str]:
        """
        Distribute a batch of errors for fixing
        
        Args:
            errors: List of error dictionaries with message, file, line info
            
        Returns:
            List of job IDs for tracking
        """
        job_ids = []
        
        for error_data in errors:
            try:
                # Create error context
                context = ErrorContext(
                    file_path=error_data.get('file', ''),
                    line_number=error_data.get('line'),
                    column_number=error_data.get('column'),
                    function_name=error_data.get('function'),
                    class_name=error_data.get('class'),
                    surrounding_code=error_data.get('code_context')
                )
                
                # Classify error
                error_type, severity = self.classifier.classify_error(
                    error_data['message'], context
                )
                
                # Determine complexity and model
                complexity = self._determine_complexity(error_data['message'], context)
                suggested_model = self.classifier.recommend_model(error_type, complexity)
                
                # Calculate priority
                priority_score = self.classifier.calculate_priority_score(
                    error_type, severity, context
                )
                
                # Create error job
                job = ErrorJob(
                    id=f"error-{int(time.time())}-{hash(error_data['message']) % 10000}",
                    error_type=error_type,
                    severity=severity,
                    message=error_data['message'],
                    context=context,
                    suggested_model=suggested_model,
                    priority_score=priority_score
                )
                
                # Submit to queue
                job_id = await self._submit_error_job(job)
                job_ids.append(job_id)
                
                logger.info(f"Distributed error job {job.id}: {error_type.value} "
                           f"(severity: {severity.value}, priority: {priority_score})")
                
            except Exception as e:
                logger.error(f"Failed to distribute error: {error_data.get('message', 'Unknown')}: {e}")
        
        await self._send_metric('ErrorsDistributed', len(job_ids))
        return job_ids
    
    async def _submit_error_job(self, job: ErrorJob) -> str:
        """Submit an error job to the SQS queue"""
        try:
            message_body = json.dumps(asdict(job), default=str)
            
            response = self.sqs.send_message(
                QueueUrl=self.error_queue_url,
                MessageBody=message_body,
                MessageAttributes={
                    'ErrorType': {
                        'StringValue': job.error_type.value,
                        'DataType': 'String'
                    },
                    'Severity': {
                        'StringValue': str(job.severity.value),
                        'DataType': 'Number'
                    },
                    'Priority': {
                        'StringValue': str(job.priority_score),
                        'DataType': 'Number'
                    },
                    'Model': {
                        'StringValue': job.suggested_model,
                        'DataType': 'String'
                    }
                }
            )
            
            message_id = response['MessageId']
            self.active_jobs[job.id] = job
            
            return message_id
            
        except ClientError as e:
            logger.error(f"Failed to submit error job {job.id}: {e}")
            raise
    
    def _determine_complexity(self, error_message: str, context: ErrorContext) -> str:
        """Determine the complexity level of an error for model selection"""
        # Simple heuristics for complexity
        complexity_indicators = {
            'simple': [
                'Missing semicolon', 'Unused variable', 'Prefer const',
                'Missing return type', 'Property does not exist'
            ],
            'complex': [
                'Type is not assignable', 'Cannot find name', 'Hook call',
                'Test failed', 'Cannot read property'
            ],
            'advanced': [
                'Generic type', 'Conditional type', 'Mapped type',
                'Complex union', 'Intersection type', 'Build failed'
            ]
        }
        
        error_lower = error_message.lower()
        
        # Check for advanced patterns first
        if any(indicator.lower() in error_lower for indicator in complexity_indicators['advanced']):
            return 'advanced'
        
        # Check for complex patterns
        if any(indicator.lower() in error_lower for indicator in complexity_indicators['complex']):
            return 'complex'
        
        # Check for simple patterns
        if any(indicator.lower() in error_lower for indicator in complexity_indicators['simple']):
            return 'simple'
        
        # Default based on error length and context
        if len(error_message) > 200 or (context.surrounding_code and len(context.surrounding_code) > 500):
            return 'complex'
        
        return 'simple'
    
    async def get_job_status(self, job_id: str) -> Dict[str, Any]:
        """Get the status of a specific error fixing job"""
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
        """Get error queue statistics"""
        try:
            response = self.sqs.get_queue_attributes(
                QueueUrl=self.error_queue_url,
                AttributeNames=[
                    'ApproximateNumberOfMessages',
                    'ApproximateNumberOfMessagesNotVisible',
                    'ApproximateNumberOfMessagesDelayed'
                ]
            )
            
            attributes = response['Attributes']
            
            return {
                'errors_pending': int(attributes.get('ApproximateNumberOfMessages', 0)),
                'errors_processing': int(attributes.get('ApproximateNumberOfMessagesNotVisible', 0)),
                'errors_delayed': int(attributes.get('ApproximateNumberOfMessagesDelayed', 0)),
                'active_jobs': len(self.active_jobs),
                'completed_jobs': len(self.completed_jobs)
            }
            
        except ClientError as e:
            logger.error(f"Failed to get queue stats: {e}")
            return {'error': str(e)}
    
    async def _send_metric(self, metric_name: str, value: float, unit: str = 'Count'):
        """Send custom metric to CloudWatch"""
        try:
            self.cloudwatch.put_metric_data(
                Namespace='AI-Testing-Agent/ErrorDistribution',
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

class ErrorAggregator:
    """Aggregates and analyzes error fixing results"""
    
    def __init__(self, result_bucket: str, region: str = 'us-east-1'):
        self.result_bucket = result_bucket
        self.s3 = boto3.client('s3', region_name=region)
    
    async def aggregate_results(self, job_ids: List[str]) -> Dict[str, Any]:
        """
        Aggregate results from multiple error fixing jobs
        
        Args:
            job_ids: List of job IDs to aggregate
            
        Returns:
            Aggregated results and statistics
        """
        results = []
        
        for job_id in job_ids:
            try:
                # Retrieve result from S3
                key = f"error-fixes/{job_id}.json"
                response = self.s3.get_object(Bucket=self.result_bucket, Key=key)
                result_data = json.loads(response['Body'].read())
                results.append(result_data)
            except ClientError as e:
                logger.warning(f"Could not retrieve result for job {job_id}: {e}")
        
        # Calculate statistics
        total_jobs = len(job_ids)
        successful_fixes = len([r for r in results if r.get('success', False)])
        failed_fixes = total_jobs - successful_fixes
        
        avg_confidence = sum(r.get('confidence_score', 0) for r in results) / len(results) if results else 0
        avg_execution_time = sum(r.get('execution_time_ms', 0) for r in results) / len(results) if results else 0
        
        # Group by error type
        error_type_stats = {}
        for result in results:
            error_type = result.get('error_type', 'unknown')
            if error_type not in error_type_stats:
                error_type_stats[error_type] = {'total': 0, 'successful': 0}
            error_type_stats[error_type]['total'] += 1
            if result.get('success', False):
                error_type_stats[error_type]['successful'] += 1
        
        return {
            'total_jobs': total_jobs,
            'successful_fixes': successful_fixes,
            'failed_fixes': failed_fixes,
            'success_rate': (successful_fixes / total_jobs * 100) if total_jobs > 0 else 0,
            'average_confidence': round(avg_confidence, 2),
            'average_execution_time_ms': round(avg_execution_time, 2),
            'error_type_breakdown': error_type_stats,
            'results': results
        }

# CLI interface for testing
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Error Distributor')
    parser.add_argument('--queue-url', required=True, help='SQS error queue URL')
    parser.add_argument('--bucket', required=True, help='S3 results bucket')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--action', choices=['distribute', 'status', 'aggregate'], 
                       default='status', help='Action to perform')
    parser.add_argument('--errors-file', help='JSON file with errors to distribute')
    parser.add_argument('--job-ids', nargs='+', help='Job IDs for status/aggregation')
    
    args = parser.parse_args()
    
    distributor = ErrorDistributor(
        error_queue_url=args.queue_url,
        result_bucket=args.bucket,
        region=args.region
    )
    
    async def main():
        if args.action == 'distribute' and args.errors_file:
            with open(args.errors_file, 'r') as f:
                errors = json.load(f)
            job_ids = await distributor.distribute_errors(errors)
            print(f"Distributed {len(job_ids)} error fixing jobs")
            for job_id in job_ids:
                print(f"  - {job_id}")
        
        elif args.action == 'status':
            if args.job_ids:
                for job_id in args.job_ids:
                    status = await distributor.get_job_status(job_id)
                    print(f"Job {job_id}: {json.dumps(status, indent=2)}")
            else:
                stats = await distributor.get_queue_stats()
                print(f"Queue stats: {json.dumps(stats, indent=2)}")
        
        elif args.action == 'aggregate' and args.job_ids:
            aggregator = ErrorAggregator(args.bucket, args.region)
            results = await aggregator.aggregate_results(args.job_ids)
            print(f"Aggregated results: {json.dumps(results, indent=2)}")
    
    asyncio.run(main()) 