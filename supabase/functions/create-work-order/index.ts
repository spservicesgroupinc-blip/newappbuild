// Supabase Edge Function: create-work-order
// Creates a Google Sheets work order from estimate data
// Location: supabase/functions/create-work-order/index.ts

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
    phone: string;
    email: string;
  };
  date: string;
  totalValue: number;
  materials: {
    openCellSets: number;
    closedCellSets: number;
    inventory: Array<{
      name: string;
      quantity: number;
      unit: string;
    }>;
  };
  expenses: {
    manHours: number;
    laborRate: number;
    tripCharge: number;
    fuelSurcharge: number;
  };
  companyProfile: {
    companyName: string;
    addressLine1: string;
    city: string;
    state: string;
    zip: string;
    phone: string;
    email: string;
  };
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
    const { estimateData, folderId }: { estimateData: EstimateData; folderId?: string } = await req.json();

    if (!estimateData) {
      throw new Error("Missing estimate data");
    }

    // Get user's Google API credentials from database
    const { data: userProfile } = await supabaseClient
      .from("company_profiles")
      .select("*")
      .eq("user_id", user.id)
      .single();

    // Create Google Sheets API client
    // Note: You'll need to set up Google API credentials in your Supabase project
    const googleApiKey = Deno.env.get("GOOGLE_API_KEY");
    const googleSheetsEndpoint = "https://sheets.googleapis.com/v4/spreadsheets";

    // Create new spreadsheet
    const spreadsheetTitle = `Work Order - ${estimateData.customer.name} - ${estimateData.date}`;
    
    const createResponse = await fetch(`${googleSheetsEndpoint}?key=${googleApiKey}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${Deno.env.get("GOOGLE_ACCESS_TOKEN")}`,
      },
      body: JSON.stringify({
        properties: {
          title: spreadsheetTitle,
        },
      }),
    });

    const spreadsheet = await createResponse.json();
    const spreadsheetId = spreadsheet.spreadsheetId;

    // Prepare work order data
    const headers = [
      ["WORK ORDER"],
      [""],
      ["Company:", userProfile?.company_name || ""],
      ["Address:", `${userProfile?.address_line1 || ''}, ${userProfile?.city || ''} ${userProfile?.state || ''} ${userProfile?.zip || ''}`],
      ["Phone:", userProfile?.phone || ""],
      ["Email:", userProfile?.email || ""],
      [""],
      ["Customer Information"],
      ["Name:", estimateData.customer.name],
      ["Address:", `${estimateData.customer.address}, ${estimateData.customer.city}, ${estimateData.customer.state} ${estimateData.customer.zip}`],
      ["Phone:", estimateData.customer.phone],
      ["Email:", estimateData.customer.email],
      [""],
      ["Job Details"],
      ["Date:", estimateData.date],
      ["Total Value:", `$${estimateData.totalValue.toFixed(2)}`],
      [""],
      ["Materials Required"],
      ["Item", "Quantity", "Unit"],
    ];

    // Add materials
    if (estimateData.materials.openCellSets > 0) {
      headers.push(["Open Cell Foam", estimateData.materials.openCellSets.toString(), "Sets"]);
    }
    if (estimateData.materials.closedCellSets > 0) {
      headers.push(["Closed Cell Foam", estimateData.materials.closedCellSets.toString(), "Sets"]);
    }

    estimateData.materials.inventory.forEach(item => {
      headers.push([item.name, item.quantity.toString(), item.unit]);
    });

    headers.push([""]);
    headers.push(["Labor & Expenses"]);
    headers.push(["Man Hours:", estimateData.expenses.manHours.toString()]);
    headers.push(["Labor Rate:", `$${estimateData.expenses.laborRate.toFixed(2)}`]);
    headers.push(["Trip Charge:", `$${estimateData.expenses.tripCharge.toFixed(2)}`]);
    headers.push(["Fuel Surcharge:", `$${estimateData.expenses.fuelSurcharge.toFixed(2)}`]);

    // Update spreadsheet with data
    const updateResponse = await fetch(
      `${googleSheetsEndpoint}/${spreadsheetId}/values/A1:Z100?key=${googleApiKey}`,
      {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${Deno.env.get("GOOGLE_ACCESS_TOKEN")}`,
        },
        body: JSON.stringify({
          valueInputOption: "RAW",
          values: headers,
        }),
      }
    );

    // Format the spreadsheet
    const formatResponse = await fetch(
      `${googleSheetsEndpoint}/${spreadsheetId}:batchUpdate?key=${googleApiKey}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${Deno.env.get("GOOGLE_ACCESS_TOKEN")}`,
        },
        body: JSON.stringify({
          requests: [
            {
              repeatCell: {
                range: {
                  startRowIndex: 0,
                  endRowIndex: 2,
                },
                cell: {
                  userEnteredFormat: {
                    backgroundColor: { red: 0.2, green: 0.4, blue: 0.8 },
                    textFormat: {
                      bold: true,
                      foregroundColor: { red: 1, green: 1, blue: 1 },
                    },
                  },
                },
                fields: "userEnteredFormat(backgroundColor,textFormat)",
              },
            },
          ],
        }),
      }
    );

    // Get the shareable URL
    const workOrderUrl = `https://docs.google.com/spreadsheets/d/${spreadsheetId}`;

    // Update estimate with work order URL in database
    await supabaseClient
      .from("estimates")
      .update({ 
        work_order_sheet_url: workOrderUrl,
        updated_at: new Date().toISOString(),
      })
      .eq("id", estimateData.id);

    return new Response(
      JSON.stringify({ 
        success: true, 
        url: workOrderUrl,
        spreadsheetId 
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error creating work order:", error);
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
