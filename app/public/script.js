document.addEventListener('DOMContentLoaded', () => {
    const ticketForm = document.getElementById('ticketForm');
    const tableBody = document.getElementById('ticketTableBody');

    // Función para cargar tickets con ruta RELATIVA
    const fetchTickets = async () => {
        try {
            // Cambio clave: ./api/tickets en lugar de /api/tickets
            const res = await fetch('./api/tickets');
            if (!res.ok) throw new Error('Error al obtener tickets');
            
            const tickets = await res.json();
            tableBody.innerHTML = '';
            
            tickets.forEach(t => {
                tableBody.innerHTML += `
                    <tr>
                        <td>#${t.id}</td>
                        <td>${t.usuario}</td>
                        <td>${t.asunto}</td>
                        <td><span class="prio-${t.prioridad}">${t.prioridad}</span></td>
                        <td>${t.estado}</td>
                    </tr>
                `;
            });
        } catch (err) {
            console.error("Error en el frontend:", err);
        }
    };

    // Evento para crear ticket con ruta RELATIVA
    ticketForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const nuevoTicket = {
            usuario: document.getElementById('usuario').value,
            asunto: document.getElementById('asunto').value,
            prioridad: document.getElementById('prioridad').value
        };

        try {
            await fetch('./api/tickets', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(nuevoTicket)
            });

            ticketForm.reset();
            fetchTickets();
        } catch (err) {
            console.error("Error al crear ticket:", err);
        }
    });

    fetchTickets();
});