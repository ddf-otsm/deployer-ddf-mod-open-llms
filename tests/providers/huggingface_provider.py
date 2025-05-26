#!/usr/bin/env python3
"""
HuggingFace Provider for Llama 4 Maverick Testing
Supports Mixture of Experts (MoE) models with 17B active / 400B total parameters
"""

import os
import time
import torch
from typing import Dict, Any, Optional
from dataclasses import dataclass
from transformers import AutoTokenizer, AutoModelForCausalLM, AutoProcessor

@dataclass
class HuggingFaceConfig:
    """Configuration for HuggingFace provider"""
    hf_token: Optional[str] = None
    cache_dir: str = "./models/huggingface"
    device_map: str = "auto"
    torch_dtype: str = "float16"
    max_memory: Optional[Dict[str, str]] = None
    
@dataclass
class GenerationResponse:
    """Response from model generation"""
    text: str
    duration: float
    usage: Dict[str, int]
    metadata: Dict[str, Any]

class HuggingFaceProvider:
    """HuggingFace provider for Llama 4 models"""
    
    def __init__(self, config: HuggingFaceConfig):
        self.config = config
        self.model = None
        self.tokenizer = None
        self.processor = None
        self.is_loaded = False
        
        # Set HF token if provided
        if config.hf_token:
            os.environ["HF_TOKEN"] = config.hf_token
    
    async def is_available(self) -> bool:
        """Check if HuggingFace provider is available"""
        try:
            # Check if HF token is set
            hf_token = os.getenv("HF_TOKEN") or self.config.hf_token
            if not hf_token:
                print("❌ HF_TOKEN environment variable not set")
                return False
            
            # Check if transformers is available
            import transformers
            print(f"✅ Transformers version: {transformers.__version__}")
            
            # Check if torch is available
            print(f"✅ PyTorch version: {torch.__version__}")
            print(f"✅ CUDA available: {torch.cuda.is_available()}")
            if torch.cuda.is_available():
                print(f"✅ GPU count: {torch.cuda.device_count()}")
                print(f"✅ GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f}GB")
            
            return True
            
        except ImportError as e:
            print(f"❌ Missing dependency: {e}")
            return False
        except Exception as e:
            print(f"❌ Provider check failed: {e}")
            return False
    
    async def load_model(self, model_name: str) -> bool:
        """Load Llama 4 Maverick model"""
        try:
            print(f"🚀 Loading {model_name}...")
            print("📊 Model specs: 17B active params, 400B total params (128 experts)")
            print("⚠️  This may take several minutes for first-time download...")
            
            # Determine torch dtype
            torch_dtype = getattr(torch, self.config.torch_dtype)
            
            # Load tokenizer/processor
            print("📝 Loading tokenizer...")
            try:
                self.processor = AutoProcessor.from_pretrained(
                    model_name,
                    cache_dir=self.config.cache_dir,
                    token=self.config.hf_token
                )
                print("✅ Processor loaded (multimodal support)")
            except:
                self.tokenizer = AutoTokenizer.from_pretrained(
                    model_name,
                    cache_dir=self.config.cache_dir,
                    token=self.config.hf_token
                )
                print("✅ Tokenizer loaded")
            
            # Load model with MoE optimizations
            print("🧠 Loading model (MoE architecture)...")
            self.model = AutoModelForCausalLM.from_pretrained(
                model_name,
                cache_dir=self.config.cache_dir,
                device_map=self.config.device_map,
                torch_dtype=torch_dtype,
                token=self.config.hf_token,
                trust_remote_code=True,
                # MoE optimizations
                attn_implementation="flash_attention_2" if torch.cuda.is_available() else "eager",
                max_memory=self.config.max_memory,
                low_cpu_mem_usage=True,
                # Quantization for memory efficiency
                load_in_8bit=False,  # Can enable if memory constrained
                load_in_4bit=False   # Can enable if memory constrained
            )
            
            self.is_loaded = True
            print("✅ Llama 4 Maverick loaded successfully")
            
            # Display memory usage
            if torch.cuda.is_available():
                memory_allocated = torch.cuda.memory_allocated() / 1e9
                memory_reserved = torch.cuda.memory_reserved() / 1e9
                print(f"📊 GPU Memory: {memory_allocated:.2f}GB allocated, {memory_reserved:.2f}GB reserved")
            
            return True
            
        except Exception as e:
            print(f"❌ Failed to load model: {e}")
            self.is_loaded = False
            return False
    
    async def generate(self, prompt: str, options: Dict[str, Any] = None) -> GenerationResponse:
        """Generate response using Llama 4 Maverick"""
        if not self.is_loaded:
            raise RuntimeError("Model not loaded")
        
        options = options or {}
        start_time = time.time()
        
        try:
            # Prepare inputs
            if self.processor:
                # Multimodal input
                messages = [{"role": "user", "content": prompt}]
                inputs = self.processor.apply_chat_template(
                    messages,
                    add_generation_prompt=True,
                    tokenize=True,
                    return_dict=True,
                    return_tensors="pt"
                ).to(self.model.device)
            else:
                # Text-only input
                inputs = self.tokenizer.encode(prompt, return_tensors="pt").to(self.model.device)
            
            # Generation parameters
            generation_kwargs = {
                "max_new_tokens": options.get("max_tokens", 500),
                "temperature": options.get("temperature", 0.1),
                "top_p": options.get("top_p", 0.9),
                "repetition_penalty": options.get("repetition_penalty", 1.1),
                "do_sample": True,
                "pad_token_id": self.tokenizer.eos_token_id if self.tokenizer else None
            }
            
            # Generate
            with torch.no_grad():
                if self.processor:
                    outputs = self.model.generate(**inputs, **generation_kwargs)
                    response_text = self.processor.batch_decode(
                        outputs[:, inputs["input_ids"].shape[-1]:], 
                        skip_special_tokens=True
                    )[0]
                else:
                    outputs = self.model.generate(inputs, **generation_kwargs)
                    response_text = self.tokenizer.decode(
                        outputs[0][inputs.shape[-1]:], 
                        skip_special_tokens=True
                    )
            
            duration = time.time() - start_time
            
            # Calculate token usage
            if self.processor:
                prompt_tokens = inputs["input_ids"].shape[-1]
                completion_tokens = outputs.shape[-1] - prompt_tokens
            else:
                prompt_tokens = inputs.shape[-1]
                completion_tokens = outputs.shape[-1] - prompt_tokens
            
            return GenerationResponse(
                text=response_text,
                duration=duration,
                usage={
                    "prompt_tokens": prompt_tokens,
                    "completion_tokens": completion_tokens,
                    "total_tokens": prompt_tokens + completion_tokens
                },
                metadata={
                    "model": "llama4-maverick",
                    "active_params": "17B",
                    "total_params": "400B",
                    "experts": 128,
                    "architecture": "MoE"
                }
            )
            
        except Exception as e:
            duration = time.time() - start_time
            raise RuntimeError(f"Generation failed after {duration:.2f}s: {e}")
    
    def get_memory_usage(self) -> Dict[str, Any]:
        """Get current memory usage"""
        if not torch.cuda.is_available():
            return {"gpu_available": False}
        
        return {
            "gpu_available": True,
            "allocated_memory": torch.cuda.memory_allocated() / 1e9,
            "reserved_memory": torch.cuda.memory_reserved() / 1e9,
            "max_memory": torch.cuda.max_memory_allocated() / 1e9
        }
    
    async def unload_model(self):
        """Unload model and free memory"""
        if self.model:
            del self.model
            self.model = None
        
        if self.tokenizer:
            del self.tokenizer
            self.tokenizer = None
            
        if self.processor:
            del self.processor
            self.processor = None
        
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        
        self.is_loaded = False
        print("✅ Model unloaded and memory freed") 