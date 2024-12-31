document.addEventListener('DOMContentLoaded', function() {
    // Initialize Materialize components
    M.AutoInit();

    // Smooth scrolling for anchor links
    const scroll = new SmoothScroll('a[href*="#"]', {
        speed: 500,
        offset: 70
    });

    // Initialize tooltips
    const tooltips = document.querySelectorAll('.tooltipped');
    M.Tooltip.init(tooltips, {
        enterDelay: 300,
        margin: 10
    });

    // Example: Handling click events on comment items
    const commentItems = document.querySelectorAll('.comment-item');
    commentItems.forEach(item => {
        item.addEventListener('click', function() {
            // Example: Toggle class on click for interaction
            this.classList.toggle('active');
        });
    });
});
