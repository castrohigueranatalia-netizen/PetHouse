// ============================================================
// ARRIENDOS CARTAGENA API · Asistente de preguntas (Claude API)
// ------------------------------------------------------------
// Responde preguntas en lenguaje natural sobre las reservas
// ("¿cuántas noches libres tiene el apto 3 en octubre?", "¿cuánto
// facturé este mes?") dándole a Claude dos herramientas de solo
// lectura sobre la base de datos: él decide cuándo consultarlas y
// hace los cálculos sobre los datos reales que le devuelven.
//
// Requiere ANTHROPIC_API_KEY en .env (https://console.anthropic.com/
// → Settings → API Keys). Sin esa clave, el asistente responde con
// un error claro en vez de fallar el servidor.
// ============================================================
import Anthropic from '@anthropic-ai/sdk'
import { pool } from '../config.js'

const MODEL = 'claude-opus-5'
const MAX_RONDAS = 6

let cliente = null
function obtenerCliente() {
  if (!process.env.ANTHROPIC_API_KEY) return null
  if (!cliente) cliente = new Anthropic()
  return cliente
}

const HERRAMIENTAS = [
  {
    name: 'listar_apartamentos',
    description: 'Devuelve los apartamentos activos (nombre, capacidad, precio base por noche). Úsala para resolver a qué apartamento se refiere una pregunta antes de buscar reservas.',
    input_schema: { type: 'object', properties: {}, required: [] }
  },
  {
    name: 'buscar_reservas',
    description: 'Busca reservas en la base de datos con filtros opcionales. Trae los datos crudos y calcula tú la respuesta (noches libres, totales facturados, conteos por fuente, etc.) — esta herramienta no hace esos cálculos por ti.',
    input_schema: {
      type: 'object',
      properties: {
        apartamento_nombre: { type: 'string', description: 'Nombre o parte del nombre del apartamento (ej. "Apto 3"). Omite para incluir todos los apartamentos.' },
        desde: { type: 'string', description: 'Fecha ISO YYYY-MM-DD: incluye reservas cuyo checkout sea posterior a esta fecha.' },
        hasta: { type: 'string', description: 'Fecha ISO YYYY-MM-DD: incluye reservas cuyo checkin sea anterior a esta fecha (usa el primer día del mes siguiente para cubrir un mes completo).' },
        estado: { type: 'string', enum: ['confirmada', 'pendiente', 'cancelada'], description: 'Omite para excluir solo las canceladas (incluye confirmadas y pendientes).' },
        fuente: { type: 'string', enum: ['booking', 'airbnb', 'whatsapp', 'directo', 'otro'] }
      },
      required: []
    }
  }
]

export async function ejecutarHerramienta(nombre, entrada) {
  if (nombre === 'listar_apartamentos') {
    const { rows } = await pool.query(
      `SELECT nombre, capacidad, precio_noche_base FROM apartamentos WHERE activo ORDER BY nombre`
    )
    return rows
  }

  if (nombre === 'buscar_reservas') {
    const condiciones = []
    const valores = []
    if (entrada.apartamento_nombre) {
      valores.push(`%${entrada.apartamento_nombre}%`)
      condiciones.push(`a.nombre ILIKE $${valores.length}`)
    }
    if (entrada.desde) { valores.push(entrada.desde); condiciones.push(`rs.checkout > $${valores.length}`) }
    if (entrada.hasta) { valores.push(entrada.hasta); condiciones.push(`rs.checkin < $${valores.length}`) }
    if (entrada.estado) {
      valores.push(entrada.estado)
      condiciones.push(`rs.estado = $${valores.length}`)
    } else {
      condiciones.push(`rs.estado <> 'cancelada'`)
    }
    if (entrada.fuente) { valores.push(entrada.fuente); condiciones.push(`rs.fuente = $${valores.length}`) }

    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''
    const { rows } = await pool.query(
      `SELECT a.nombre AS apartamento, rs.checkin, rs.checkout, rs.noches, rs.precio_total,
              rs.fuente, rs.estado, rs.huesped_nombre
         FROM reservas rs JOIN apartamentos a ON a.id = rs.apartamento_id
        ${where}
        ORDER BY rs.checkin
        LIMIT 300`,
      valores
    )
    return rows
  }

  return { error: `Herramienta desconocida: ${nombre}` }
}

function systemPrompt() {
  const hoy = new Date().toISOString().slice(0, 10)
  return `Eres el asistente de "Arriendos Cartagena", una app interna para un arrendador de 7 apartamentos en Cartagena, Colombia. Respondes preguntas del propietario sobre sus reservas, ocupación y facturación.

Hoy es ${hoy}.

Reglas:
- SIEMPRE usa las herramientas para consultar datos reales antes de responder cualquier pregunta con números, fechas o nombres — nunca inventes ni asumas cifras.
- Los precios están en pesos colombianos (COP); formatéalos como "$250.000".
- "Noches libres" de un rango = noches del rango menos las ocupadas por reservas confirmadas o pendientes que se crucen con ese rango.
- Sé breve y directo, en español, como si hablaras con el dueño del negocio. Un par de frases o una lista corta basta.
- Si la pregunta no tiene que ver con las reservas o los apartamentos, dilo brevemente y redirige a lo que sí puedes responder.`
}

export async function preguntarAsistente(historial) {
  const client = obtenerCliente()
  if (!client) {
    return { error: 'El asistente no está configurado: falta ANTHROPIC_API_KEY en el archivo .env del servidor.' }
  }

  const messages = historial.map((m) => ({
    role: m.rol === 'asistente' ? 'assistant' : 'user',
    content: m.texto
  }))

  try {
    for (let ronda = 0; ronda < MAX_RONDAS; ronda++) {
      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 1024,
        system: systemPrompt(),
        tools: HERRAMIENTAS,
        messages
      })

      if (response.stop_reason === 'refusal') {
        return { respuesta: 'No puedo responder eso.' }
      }

      if (response.stop_reason === 'pause_turn') {
        messages.push({ role: 'assistant', content: response.content })
        continue
      }

      const bloquesHerramienta = response.content.filter((b) => b.type === 'tool_use')
      if (response.stop_reason !== 'tool_use' || !bloquesHerramienta.length) {
        const texto = response.content.filter((b) => b.type === 'text').map((b) => b.text).join('\n').trim()
        return { respuesta: texto || 'No tengo una respuesta para eso.' }
      }

      messages.push({ role: 'assistant', content: response.content })

      const resultados = []
      for (const bloque of bloquesHerramienta) {
        try {
          const resultado = await ejecutarHerramienta(bloque.name, bloque.input || {})
          resultados.push({ type: 'tool_result', tool_use_id: bloque.id, content: JSON.stringify(resultado) })
        } catch (err) {
          resultados.push({ type: 'tool_result', tool_use_id: bloque.id, content: err.message, is_error: true })
        }
      }
      messages.push({ role: 'user', content: resultados })
    }

    return { error: 'El asistente tardó demasiado respondiendo esta pregunta. Intenta reformularla.' }
  } catch (err) {
    if (err instanceof Anthropic.AuthenticationError) {
      return { error: 'La clave ANTHROPIC_API_KEY no es válida.' }
    }
    if (err instanceof Anthropic.RateLimitError) {
      return { error: 'Se alcanzó el límite de uso de la API de Claude. Intenta de nuevo en un momento.' }
    }
    if (err instanceof Anthropic.APIError) {
      return { error: `Error del asistente: ${err.message}` }
    }
    throw err
  }
}
