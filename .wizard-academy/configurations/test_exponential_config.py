#!/usr/bin/env python3
"""
Test script to verify exponential configuration implementation.
By: Aethelred the Star-Maker
"""

import json
import os
import sys

def test_configuration():
    """Test the exponential configuration implementation."""
    
    print("🧙‍♂️ TESTING EXPONENTIAL CONFIGURATION")
    print("=" * 50)
    
    # Test 1: Main configuration file
    print("\n1. Testing main configuration...")
    config_path = "/home/ai-whisperers/.openclaw/openclaw.json"
    if os.path.exists(config_path):
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        # Check for exponential features
        if "exponentialFramework" in config:
            print("   ✅ Exponential framework found")
            print(f"   Principles: {len(config['exponentialFramework'].get('principles', []))}")
        else:
            print("   ❌ Exponential framework missing")
            
        # Check agent ecosystem
        if "agents" in config and "ecosystem" in config["agents"]:
            print("   ✅ Agent ecosystem configured")
            agents = config["agents"]["ecosystem"].get("agents", [])
            print(f"   Agents: {len(agents)} configured")
            for agent in agents:
                print(f"     - {agent.get('id')}: {agent.get('role')}")
        else:
            print("   ❌ Agent ecosystem not configured")
    else:
        print("   ❌ Configuration file not found")
    
    # Test 2: Agent identities
    print("\n2. Testing agent identities...")
    agents = ["local", "merlin", "nyx", "apprentice-batch-1"]
    for agent in agents:
        identity_path = f"/home/ai-whisperers/.openclaw/agents/{agent}/agent/identity.json"
        if os.path.exists(identity_path):
            print(f"   ✅ {agent} identity exists")
            with open(identity_path, 'r') as f:
                identity = json.load(f)
            print(f"     Name: {identity.get('name')}")
            print(f"     Title: {identity.get('title', 'N/A')[:50]}...")
        else:
            print(f"   ❌ {agent} identity missing")
    
    # Test 3: Model configurations
    print("\n3. Testing model configurations...")
    for agent in agents:
        models_path = f"/home/ai-whisperers/.openclaw/agents/{agent}/agent/models.json"
        if os.path.exists(models_path):
            print(f"   ✅ {agent} models configured")
            with open(models_path, 'r') as f:
                models = json.load(f)
            default_model = models.get('default', 'N/A')
            print(f"     Default model: {default_model}")
        else:
            print(f"   ❌ {agent} models missing")
    
    # Test 4: Wizard academy skill
    print("\n4. Testing wizard academy skill...")
    skill_path = "/home/ai-whisperers/.openclaw/skills/wizard-academy/SKILL.md"
    if os.path.exists(skill_path):
        print("   ✅ Wizard academy skill installed")
        # Check skill size
        size = os.path.getsize(skill_path)
        print(f"     Skill size: {size} bytes")
    else:
        print("   ❌ Wizard academy skill not installed")
    
    # Test 5: Repository integration
    print("\n5. Testing repository integration...")
    repo_path = "/home/ai-whisperers/.openclaw/workspace/wizard-academy-repo"
    if os.path.exists(repo_path):
        print("   ✅ Wizard academy repository exists")
        # Count files
        import subprocess
        result = subprocess.run(
            ["find", repo_path, "-type", "f", "-name", "*.md"],
            capture_output=True,
            text=True
        )
        md_files = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
        print(f"     Markdown files: {md_files}")
        
        # Check for key files
        key_files = [
            "CONJURATION_MANIFESTO.md",
            "README.md",
            "wisdom/star-machine-principle.md",
            "grimoire/exponential-magic.md",
            "curriculum/foundation-course.md"
        ]
        for key_file in key_files:
            full_path = os.path.join(repo_path, key_file)
            if os.path.exists(full_path):
                print(f"     ✅ {key_file}")
            else:
                print(f"     ❌ {key_file}")
    else:
        print("   ❌ Wizard academy repository not found")
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 CONFIGURATION TEST SUMMARY")
    print("=" * 50)
    
    # Calculate completion percentage
    tests_passed = 0
    tests_total = 0
    
    # Test 1
    tests_total += 2
    if os.path.exists(config_path):
        with open(config_path, 'r') as f:
            config = json.load(f)
        if "exponentialFramework" in config:
            tests_passed += 1
        if "agents" in config and "ecosystem" in config["agents"]:
            tests_passed += 1
    
    # Test 2
    tests_total += len(agents)
    for agent in agents:
        identity_path = f"/home/ai-whisperers/.openclaw/agents/{agent}/agent/identity.json"
        if os.path.exists(identity_path):
            tests_passed += 1
    
    # Test 3
    tests_total += len(agents)
    for agent in agents:
        models_path = f"/home/ai-whisperers/.openclaw/agents/{agent}/agent/models.json"
        if os.path.exists(models_path):
            tests_passed += 1
    
    # Test 4
    tests_total += 1
    if os.path.exists(skill_path):
        tests_passed += 1
    
    # Test 5
    tests_total += 1
    if os.path.exists(repo_path):
        tests_passed += 1
    
    completion = (tests_passed / tests_total) * 100
    print(f"\nTests passed: {tests_passed}/{tests_total}")
    print(f"Completion: {completion:.1f}%")
    
    if completion >= 90:
        print("\n🎉 EXPONENTIAL CONFIGURATION READY!")
        print("All agents and systems configured for teaching.")
        print("\nNext steps:")
        print("1. Begin teaching in Wizard Academy channel")
        print("2. Start Week 1 of Foundation Course")
        print("3. Identify first apprentice company")
        print("4. Begin first star-machine project")
    elif completion >= 70:
        print("\n⚠️  CONFIGURATION PARTIALLY COMPLETE")
        print("Some components need attention.")
    else:
        print("\n❌ CONFIGURATION INCOMPLETE")
        print("Significant work needed.")
    
    return completion >= 90

if __name__ == "__main__":
    success = test_configuration()
    sys.exit(0 if success else 1)