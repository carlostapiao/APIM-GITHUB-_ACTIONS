document.addEventListener('DOMContentLoaded', () => {
    const ticketForm = document.getElementById('ticketForm');
    const tableBody = document.getElementById('ticketTableBody');

    // Función para cargar tickets
    const fetchTickets = async () => {
        const res = await fetch('/api/tickets');
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
    };

    // Evento para crear ticket
    ticketForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const nuevoTicket = {
            usuario: document.getElementById('usuario').value,
            asunto: document.getElementById('asunto').value,
            prioridad: document.getElementById('prioridad').value
        };

        await fetch('/api/tickets', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(nuevoTicket)
        });

        ticketForm.reset();
        fetchTickets();
    });

    fetchTickets();
});