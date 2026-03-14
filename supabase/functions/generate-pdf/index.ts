// Supabase Edge Function: generate-pdf
// Generates a PDF estimate/invoice from estimate data
// Location: supabase/functions/generate-pdf/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface EstimateData {
  id: string;
  customerId: string;
  customer: {
    name: string;
    address: string;
    city: string;
    state: string;
    zip: string;
  };
  date: string;
  totalValue: number;
  status: string;
  invoiceNumber?: string;
  materials: {
    openCellSets: number;
    closedCellSets: number;
    inventory: Array<{
      name: string;
      quantity: number;
      unit: number;
      unitCost: number;
    }>;
  };
  results: {
    totalOpenCellBdFt: number;
    totalClosedCellBdFt: number;
    laborCost: number;
    materialCost: number;
    totalCost: number;
  };
  expenses: {
    manHours: number;
    laborRate: number;
    tripCharge: number;
    fuelSurcharge: number;
    other: {
      description: string;
      amount: number;
    };
  };
  companyProfile: {
    companyName: string;
    addressLine1: string;
    addressLine2: string;
    city: string;
    state: string;
    zip: string;
    phone: string;
    email: string;
    website: string;
    logoUrl?: string;
  };
  notes?: string;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    // Get authenticated user
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    
    if (authError || !user) {
      throw new Error("Unauthorized");
    }

    // Parse request body
    const { estimateData, type = "estimate" }: { estimateData: EstimateData; type?: "estimate" | "invoice" | "work-order" } = await req.json();

    if (!estimateData) {
      throw new Error("Missing estimate data");
    }

    // Generate PDF HTML content
    const htmlContent = generatePdfHtml(estimateData, type);

    // Use a PDF generation service (e.g., Puppeteer via API, or pdfmake)
    // For this example, we'll use a hypothetical PDF generation API
    const pdfResponse = await fetch("https://api.pdflayer.com/api/convert", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${Deno.env.get("PDF_GENERATION_API_KEY")}`,
      },
      body: JSON.stringify({
        html: htmlContent,
        format: "A4",
        orientation: "portrait",
      }),
    });

    const pdfBlob = await pdfResponse.blob();
    const base64Pdf = await blobToBase64(pdfBlob);

    // Upload PDF to Supabase Storage
    const fileName = `${type}-${estimateData.id}-${Date.now()}.pdf`;
    const filePath = `${user.id}/estimates/${estimateData.id}/${fileName}`;

    const { data: uploadData, error: uploadError } = await supabaseClient.storage
      .from("estimate-pdfs")
      .upload(filePath, pdfBlob, { upsert: true });

    if (uploadError) {
      throw uploadError;
    }

    // Get public URL
    const { data: urlData } = supabaseClient.storage
      .from("estimate-pdfs")
      .getPublicUrl(filePath);

    // Update estimate with PDF link
    const updateField = type === "invoice" ? "pdf_link" : "pdf_link";
    await supabaseClient
      .from("estimates")
      .update({ 
        [updateField]: urlData.publicUrl,
        updated_at: new Date().toISOString(),
      })
      .eq("id", estimateData.id);

    return new Response(
      JSON.stringify({ 
        success: true, 
        url: urlData.publicUrl,
        path: filePath 
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error generating PDF:", error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error instanceof Error ? error.message : "Unknown error" 
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});

function generatePdfHtml(data: EstimateData, type: string): string {
  const isInvoice = type === "invoice";
  
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    .header { display: flex; justify-content: space-between; margin-bottom: 30px; }
    .company-info { font-size: 12px; }
    .title { font-size: 24px; font-weight: bold; color: #333; }
    .customer-section { margin-bottom: 20px; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #4CAF50; color: white; }
    .total-row { font-weight: bold; background-color: #f5f5f5; }
    .footer { margin-top: 40px; font-size: 10px; color: #666; }
  </style>
</head>
<body>
  <div class="header">
    <div class="company-info">
      <h2>${data.companyProfile.companyName}</h2>
      <p>${data.companyProfile.addressLine1}<br>
      ${data.companyProfile.addressLine2 ? data.companyProfile.addressLine2 + '<br>' : ''}
      ${data.companyProfile.city}, ${data.companyProfile.state} ${data.companyProfile.zip}</p>
      <p>Phone: ${data.companyProfile.phone}<br>
      Email: ${data.companyProfile.email}</p>
    </div>
    <div>
      <div class="title">${isInvoice ? "INVOICE" : "ESTIMATE"}</div>
      <p>Date: ${new Date(data.date).toLocaleDateString()}</p>
      ${data.invoiceNumber ? `<p>Invoice #: ${data.invoiceNumber}</p>` : ''}
    </div>
  </div>

  <div class="customer-section">
    <h3>Customer</h3>
    <p><strong>${data.customer.name}</strong><br>
    ${data.customer.address}<br>
    ${data.customer.city}, ${data.customer.state} ${data.customer.zip}</p>
  </div>

  <h3>Materials</h3>
  <table>
    <tr>
      <th>Item</th>
      <th>Quantity</th>
      <th>Unit</th>
      <th>Unit Cost</th>
      <th>Total</th>
    </tr>
    ${data.materials.openCellSets > 0 ? `
    <tr>
      <td>Open Cell Foam</td>
      <td>${data.materials.openCellSets}</td>
      <td>Sets</td>
      <td>$${(data.results.materialCost / (data.materials.openCellSets + data.materials.closedCellSets || 1)).toFixed(2)}</td>
      <td>$${(data.materials.openCellSets * (data.results.materialCost / (data.materials.openCellSets + data.materials.closedCellSets || 1))).toFixed(2)}</td>
    </tr>
    ` : ''}
    ${data.materials.closedCellSets > 0 ? `
    <tr>
      <td>Closed Cell Foam</td>
      <td>${data.materials.closedCellSets}</td>
      <td>Sets</td>
      <td>$${(data.results.materialCost / (data.materials.openCellSets + data.materials.closedCellSets || 1)).toFixed(2)}</td>
      <td>$${(data.materials.closedCellSets * (data.results.materialCost / (data.materials.openCellSets + data.materials.closedCellSets || 1))).toFixed(2)}</td>
    </tr>
    ` : ''}
    ${data.materials.inventory.map(item => `
    <tr>
      <td>${item.name}</td>
      <td>${item.quantity}</td>
      <td>${item.unit}</td>
      <td>$${item.unitCost.toFixed(2)}</td>
      <td>$${(item.quantity * item.unitCost).toFixed(2)}</td>
    </tr>
    `).join('')}
  </table>

  <h3>Labor & Expenses</h3>
  <table>
    <tr>
      <td>Labor (${data.expenses.manHours} hrs @ $${data.expenses.laborRate.toFixed(2)}/hr)</td>
      <td>$${(data.expenses.manHours * data.expenses.laborRate).toFixed(2)}</td>
    </tr>
    <tr>
      <td>Trip Charge</td>
      <td>$${data.expenses.tripCharge.toFixed(2)}</td>
    </tr>
    <tr>
      <td>Fuel Surcharge</td>
      <td>$${data.expenses.fuelSurcharge.toFixed(2)}</td>
    </tr>
    ${data.expenses.other.amount > 0 ? `
    <tr>
      <td>${data.expenses.other.description}</td>
      <td>$${data.expenses.other.amount.toFixed(2)}</td>
    </tr>
    ` : ''}
    <tr class="total-row">
      <td><strong>TOTAL</strong></td>
      <td><strong>$${data.totalValue.toFixed(2)}</strong></td>
    </tr>
  </table>

  ${data.notes ? `
  <div class="notes">
    <h3>Notes</h3>
    <p>${data.notes}</p>
  </div>
  ` : ''}

  <div class="footer">
    <p>Thank you for your business!</p>
    <p>${data.companyProfile.website ? 'Visit us at: ' + data.companyProfile.website : ''}</p>
  </div>
</body>
</html>
  `;
}

async function blobToBase64(blob: Blob): Promise<string> {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}
