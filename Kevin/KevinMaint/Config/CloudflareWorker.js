// Cloudflare Worker for FREE AI Analysis
// Deploy this to Cloudflare Workers for $0/month
// Set HF_API_KEY as environment variable in Cloudflare dashboard

export default {
  async fetch(request, env) {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return new Response('POST only', { status: 405, headers: corsHeaders });
    }

    try {
      const formData = await request.formData();
      const imageFile = formData.get('image');
      const ocrText = formData.get('ocrText') || '';

      if (!imageFile) {
        return new Response('No image provided', { status: 400, headers: corsHeaders });
      }

      // Step 1: Get image caption with Florence-2 (free on Hugging Face)
      const captionResponse = await fetch(
        'https://api-inference.huggingface.co/models/microsoft/Florence-2-large',
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${env.HF_API_KEY}`,
            'Content-Type': 'application/octet-stream',
          },
          body: imageFile,
        }
      );

      const captionResult = await captionResponse.json();
      const caption = Array.isArray(captionResult) ? 
        captionResult[0]?.generated_text || 'Image analysis unavailable' :
        captionResult.generated_text || 'Image analysis unavailable';

      // Step 2: Convert caption + OCR to structured maintenance JSON
      const systemPrompt = `You are a professional restaurant maintenance expert. Convert image captions and OCR text into structured maintenance issue JSON.

Categories: Furniture, Door/Lock, Electrical, Plumbing, Wall/Ceiling, Flooring, Equipment, Signage, Other

Return ONLY valid JSON matching this exact schema:
{
  "issue_category": "string",
  "component": "string", 
  "failure_mode": ["array of strings"],
  "severity_0to3": 0-3,
  "safety_flag": boolean,
  "summary": "string",
  "recommended_fix_steps": ["array of strings"],
  "tools": ["array of strings"],
  "materials": ["array of strings"], 
  "est_time_min": number,
  "est_cost_usd": number,
  "confidence_0to1": 0.0-1.0,
  "notes": "string or null"
}`;

      const userPrompt = `Caption: ${caption}\nOCR Text: ${ocrText}\n\nAnalyze for maintenance issues and return JSON:`;

      const llmResponse = await fetch(
        'https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium',
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${env.HF_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            inputs: `${systemPrompt}\n\n${userPrompt}`,
            parameters: {
              max_new_tokens: 512,
              temperature: 0.3,
              return_full_text: false
            }
          }),
        }
      );

      const llmResult = await llmResponse.json();
      let generatedText = Array.isArray(llmResult) ? 
        llmResult[0]?.generated_text || '' : 
        llmResult.generated_text || '';

      // Extract JSON from response
      const jsonStart = generatedText.indexOf('{');
      const jsonEnd = generatedText.lastIndexOf('}');
      
      if (jsonStart === -1 || jsonEnd === -1) {
        // Fallback structured response
        const fallbackResponse = {
          issue_category: "Other",
          component: "Unknown component",
          failure_mode: ["requires inspection"],
          severity_0to3: 1,
          safety_flag: false,
          summary: `Maintenance issue detected: ${caption}`,
          recommended_fix_steps: [
            "Inspect the affected area closely",
            "Determine specific repair needs",
            "Gather appropriate tools and materials",
            "Complete repair following safety protocols"
          ],
          tools: ["Basic hand tools", "Safety equipment"],
          materials: ["TBD based on inspection"],
          est_time_min: 30,
          est_cost_usd: 25.0,
          confidence_0to1: 0.6,
          notes: "AI analysis requires manual verification"
        };
        
        return new Response(JSON.stringify(fallbackResponse), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const jsonString = generatedText.slice(jsonStart, jsonEnd + 1);
      
      // Validate JSON
      try {
        const parsedJson = JSON.parse(jsonString);
        return new Response(JSON.stringify(parsedJson), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      } catch (parseError) {
        // Return fallback if JSON parsing fails
        const fallbackResponse = {
          issue_category: "Other",
          component: "Detected issue",
          failure_mode: ["needs assessment"],
          severity_0to3: 1,
          safety_flag: false,
          summary: caption,
          recommended_fix_steps: ["Professional assessment recommended"],
          tools: ["Assessment tools"],
          materials: ["TBD"],
          est_time_min: 20,
          est_cost_usd: 15.0,
          confidence_0to1: 0.5,
          notes: "Automated analysis - verify manually"
        };
        
        return new Response(JSON.stringify(fallbackResponse), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

    } catch (error) {
      console.error('Worker error:', error);
      
      const errorResponse = {
        issue_category: "Other",
        component: "Analysis unavailable", 
        failure_mode: ["system error"],
        severity_0to3: 1,
        safety_flag: false,
        summary: "Unable to analyze image at this time",
        recommended_fix_steps: ["Manual inspection required"],
        tools: ["Visual inspection"],
        materials: ["None"],
        est_time_min: 10,
        est_cost_usd: 0,
        confidence_0to1: 0.0,
        notes: "AI service temporarily unavailable"
      };
      
      return new Response(JSON.stringify(errorResponse), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
  }
};

/*
DEPLOYMENT INSTRUCTIONS:

1. Create Cloudflare account (free tier) at cloudflare.com
2. Install Wrangler CLI: npm install -g wrangler
3. Login: wrangler login
4. Create new worker: wrangler init kevin-ai-worker
5. Replace worker.js with this code
6. Set your HF API key: wrangler secret put HF_API_KEY
   Enter: YOUR_HUGGING_FACE_API_KEY_HERE
7. Deploy: wrangler deploy
8. Copy your worker URL and update HuggingFaceService.swift

Your worker URL will be: https://kevin-ai-worker.YOUR_SUBDOMAIN.workers.dev

QUICK DEPLOY COMMANDS:
npm install -g wrangler
wrangler login
wrangler init kevin-ai-worker
# Copy this file content to worker.js
wrangler secret put HF_API_KEY
wrangler deploy
*/
