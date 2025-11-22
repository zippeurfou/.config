# AGENTS.md - Project Guide for AI Assistants

# General Instructions for AI Assistants

1. **Memory First**  
   - Whenever you encounter a topic (e.g. “Grubhub”) or a request that might draw on internal data (e.g. SQL against our internal database), **first** check your existing memory/knowledge.

2. **Agents and Sub-agents First**  
    - **Always prioritize using sub-agents when available** for any task that matches their specialized capabilities
    - Before proceeding with any other approach, systematically check if a sub-agent can handle the request besides the general sub-agent.
    - **Default to sub-agents** rather than attempting tasks manually - they are specialized for their domains and will be more efficient

3. **Context Retrieval**  
   - If you find nothing in memory or need more context, automatically query sub-agents.

4. **Memory Enrichment**  
   - After retrieving information, ask me:  
     > “Should I add these new details to memory?”  
   - **If I say yes**, proceed as follows:

   a. **Ontology Assessment**  
   - Take time to map the new information onto your existing ontology or if the ontology would benefit from refactoring given the new information.  
   - **If no refactoring is needed**, integrate it directly.  

   b. **Ontology Refactoring**  
   - **If refactoring is required**, present me with:  
     - A clear plan for how you’ll reorganize or extend the ontology  
     - An assurance that no existing information will be lost  
     - Any specific questions you have before proceeding  
   - Once I confirm, carry out the refactor and then integrate the new information.

5. **Veracity Check**  
   - Before writing anything into memory, always confirm with me that the retrieved information is accurate.

# Programming and Code-Related Tasks

## Python

1. Use uv to run python scripts and install packages.
