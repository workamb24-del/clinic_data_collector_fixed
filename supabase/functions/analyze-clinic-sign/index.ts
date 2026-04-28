// Supabase Edge Function: analyze-clinic-sign
// Deploy: supabase functions deploy analyze-clinic-sign
// Secrets:
//   supabase secrets set GEMINI_API_KEY=YOUR_KEY
//   supabase secrets set OCR_SPACE_API_KEY=YOUR_KEY   (optional; defaults to free demo key)

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type ClinicResult = {
  clinic_name: string
  doctor_name: string
  mobile: string
  phone: string
  specialty: string
  city: string
  area: string
  address_text: string
  raw_text: string
  confidence: number
}

const EMPTY_RESULT: ClinicResult = {
  clinic_name: '',
  doctor_name: '',
  mobile: '',
  phone: '',
  specialty: '',
  city: '',
  area: '',
  address_text: '',
  raw_text: '',
  confidence: 0,
}

function cleanJsonText(text: string) {
  return text.replace(/```json/gi, '').replace(/```/g, '').trim()
}

function toEnglishDigits(value: string) {
  const arabic = '٠١٢٣٤٥٦٧٨٩'
  const persian = '۰۱۲۳۴۵۶۷۸۹'
  return String(value ?? '')
    .replace(/[٠-٩]/g, d => String(arabic.indexOf(d)))
    .replace(/[۰-۹]/g, d => String(persian.indexOf(d)))
}

function normalizePhone(value: string) {
  return toEnglishDigits(value)
    .replace(/[()\[\]{}]/g, ' ')
    .replace(/[^0-9+]/g, '')
    .replace(/^00963/, '+963')
    .replace(/^963(?=9)/, '+963')
    .replace(/^0090/, '+90')
    .replace(/^90(?=5)/, '+90')
}

function normalizeResult(parsed: Record<string, unknown>): ClinicResult {
  return {
    clinic_name: String(parsed.clinic_name ?? '').trim(),
    doctor_name: String(parsed.doctor_name ?? '').trim(),
    mobile: normalizePhone(String(parsed.mobile ?? '')),
    phone: normalizePhone(String(parsed.phone ?? '')),
    specialty: String(parsed.specialty ?? parsed.category ?? '').trim(),
    city: String(parsed.city ?? '').trim(),
    area: String(parsed.area ?? '').trim(),
    address_text: String(parsed.address_text ?? '').trim(),
    raw_text: String(parsed.raw_text ?? '').trim(),
    confidence: typeof parsed.confidence === 'number' ? Math.max(0, Math.min(1, parsed.confidence)) : 0.6,
  }
}

function detectSpecialty(text: string) {
  const t = text.replace(/\s+/g, ' ')
  if (/أسنان|اسنان|سنية|تقويم|زرع|زراعة|فك|فكين|لثة|لبية|جذور/i.test(t)) return 'طب أسنان'
  if (/جلدية|تجميل|ليزر|بشرة/i.test(t)) return 'جلدية وتجميل'
  if (/عيون|عينية|بصريات/i.test(t)) return 'عيون'
  if (/أطفال|اطفال|طفل/i.test(t)) return 'أطفال'
  if (/نسائية|ولادة|توليد|عقم/i.test(t)) return 'نسائية وتوليد'
  if (/مخبر|تحاليل|تحليل/i.test(t)) return 'مخبر تحاليل'
  if (/أشعة|اشعة|رنين|طبقي|تصوير/i.test(t)) return 'أشعة وتصوير'
  if (/صيدلية|Pharmacy/i.test(t)) return 'صيدلية'
  if (/مركز|مجمع|عيادات/i.test(t)) return 'مركز طبي'
  return 'غير محدد'
}

function parseRawText(raw: string): ClinicResult {
  const text = toEnglishDigits(raw || '').replace(/\r/g, '\n')
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean)
  const phoneCandidates = Array.from(text.matchAll(/(?:\+?963|00963|0)?9\d[\d\s\-().]{6,12}|(?:\+?90|0090)?5\d[\d\s\-().]{7,13}|0\d{1,3}[\d\s\-().]{5,10}/g))
    .map(m => normalizePhone(m[0]))
    .filter(v => v.replace(/\D/g, '').length >= 7)
  const uniquePhones = [...new Set(phoneCandidates)]
  const mobile = uniquePhones.find(p => /(?:^09|^\+9639|^9|^\+905|^05)/.test(p)) ?? ''
  const phone = uniquePhones.find(p => p !== mobile) ?? ''

  const doctorLine = lines.find(l => /^(د\.?|دكتور|الدكتور|دكتورة|الدكتورة|Dr\.?)/i.test(l)) ?? ''
  const ignore = /(هاتف|موبايل|جوال|Tel|Phone|Mobile|واتساب|Whatsapp|www|@|facebook|instagram|شارع|بناء|طابق|مقابل|جانب|قرب)/i
  const clinicLine = lines.find(l =>
    l !== doctorLine &&
    !ignore.test(l) &&
    !/\d{5,}/.test(l) &&
    /(عيادة|مركز|مجمع|مخبر|صيدلية|Clinic|Center|Dental|Medical|Lab)/i.test(l)
  ) ?? lines.find(l => l !== doctorLine && !ignore.test(l) && !/\d{5,}/.test(l)) ?? ''

  const addressLine = lines.find(l => /(شارع|ساحة|مقابل|جانب|قرب|بناء|طابق|حي|منطقة|مول|مزة|حلب|دمشق|إسطنبول|اسطنبول|تركيا|سوريا)/i.test(l)) ?? ''

  const city = /(دمشق)/.test(text) ? 'دمشق'
    : /(حلب)/.test(text) ? 'حلب'
    : /(حمص)/.test(text) ? 'حمص'
    : /(حماة)/.test(text) ? 'حماة'
    : /(اللاذقية)/.test(text) ? 'اللاذقية'
    : /(إسطنبول|اسطنبول|Istanbul)/i.test(text) ? 'إسطنبول'
    : ''

  return {
    ...EMPTY_RESULT,
    clinic_name: clinicLine,
    doctor_name: doctorLine,
    mobile,
    phone,
    specialty: detectSpecialty(text),
    city,
    area: '',
    address_text: addressLine,
    raw_text: text.trim(),
    confidence: text.trim().length > 0 ? 0.48 : 0.1,
  }
}

async function analyzeWithGemini(imageBase64: string, mimeType: string): Promise<ClinicResult> {
  const apiKey = Deno.env.get('GEMINI_API_KEY')
  if (!apiKey) throw new Error('Missing GEMINI_API_KEY secret')

  const prompt = `
أنت نظام OCR + Data Extraction مخصص لصور لوحات العيادات والمراكز الطبية في سوريا/تركيا.
حلل الصورة بدقة واستخرج البيانات المنشورة على اللوحة فقط.

قواعد مهمة:
- أعد JSON فقط، بدون markdown وبدون شرح.
- إذا لم تجد قيمة اكتب string فارغ.
- لا تخترع أرقام أو أسماء.
- صحح الأرقام العربية والهندية إلى أرقام إنجليزية.
- استخرج كل النص المقروء في raw_text.
- صنّف الاختصاص الطبي في specialty مثل: طب أسنان، جلدية وتجميل، عيون، أطفال، نسائية وتوليد، مخبر تحاليل، أشعة وتصوير، مركز طبي، صيدلية، غير محدد.
- clinic_name هو اسم المركز/العيادة/المخبر/الصيدلية وليس اسم الطبيب.
- doctor_name يبدأ غالبًا بـ د. / Dr / الدكتور / الدكتورة.
- mobile للرقم الجوال، خصوصًا 09xxxxxxxx أو +9639xxxxxxxx أو +90.
- phone للرقم الأرضي مثل 011 أو 021 أو أرقام المكتب.
- address_text للعناوين المكتوبة على اللوحة.
- city والarea من النص فقط إذا مذكورين.
- confidence رقم بين 0 و 1 حسب وضوح الصورة وثقتك.

الشكل المطلوب حرفيًا:
{
  "clinic_name": "",
  "doctor_name": "",
  "mobile": "",
  "phone": "",
  "specialty": "",
  "city": "",
  "area": "",
  "address_text": "",
  "raw_text": "",
  "confidence": 0.0
}
`

  const model = Deno.env.get('GEMINI_MODEL') || 'gemini-2.5-flash'
  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`
  const response = await fetch(geminiUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{
        parts: [
          { text: prompt },
          { inline_data: { mime_type: mimeType, data: imageBase64 } },
        ],
      }],
      generationConfig: {
        temperature: 0.0,
        topP: 0.1,
        response_mime_type: 'application/json',
      },
    }),
  })

  if (!response.ok) throw new Error(`Gemini failed: ${await response.text()}`)
  const data = await response.json()
  const text = cleanJsonText(data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '{}')
  return normalizeResult(JSON.parse(text))
}

async function analyzeWithOcrSpace(imageBase64: string, mimeType: string): Promise<ClinicResult> {
  const apiKey = Deno.env.get('OCR_SPACE_API_KEY') || 'helloworld'
  const form = new FormData()
  form.set('apikey', apiKey)
  form.set('language', 'ara')
  form.set('OCREngine', '2')
  form.set('isOverlayRequired', 'false')
  form.set('scale', 'true')
  form.set('detectOrientation', 'true')
  form.set('base64Image', `data:${mimeType};base64,${imageBase64}`)

  const response = await fetch('https://api.ocr.space/parse/image', {
    method: 'POST',
    body: form,
  })
  if (!response.ok) throw new Error(`OCR.space failed: ${await response.text()}`)
  const data = await response.json()
  if (data?.IsErroredOnProcessing) {
    throw new Error(`OCR.space processing error: ${JSON.stringify(data?.ErrorMessage ?? data)}`)
  }
  const rawText = (data?.ParsedResults ?? [])
    .map((r: Record<string, unknown>) => String(r?.ParsedText ?? ''))
    .join('\n')
    .trim()
  const parsed = parseRawText(rawText)
  return { ...parsed, confidence: rawText ? 0.42 : 0.05 }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { image_base64, mime_type = 'image/jpeg' } = await req.json()
    if (!image_base64) throw new Error('image_base64 is required')

    const errors: string[] = []

    try {
      const geminiResult = await analyzeWithGemini(image_base64, mime_type)
      return new Response(JSON.stringify({ ...geminiResult, source: 'gemini' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    } catch (err) {
      errors.push(String(err?.message ?? err))
    }

    try {
      const ocrSpaceResult = await analyzeWithOcrSpace(image_base64, mime_type)
      return new Response(JSON.stringify({ ...ocrSpaceResult, source: 'ocr_space', warnings: errors }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    } catch (err) {
      errors.push(String(err?.message ?? err))
    }

    return new Response(JSON.stringify({ ...EMPTY_RESULT, error: errors.join(' | ') }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ ...EMPTY_RESULT, error: String(err?.message ?? err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
