// Helper functions to brute force fix a few issues with responsiveness
function index_page_create_ellipsis() {
    /*
    A simple function that iterates through all post titles on the index.html
    page and adds ellipses if the length of characters exceeds 20.
    */

    let threshold = 450;
    let clientWidth = Math.max(document.documentElement.clientWidth, window.innerWidth || 0);

    if (clientWidth < threshold) {
        let link_titles = document.querySelectorAll('*[id]');
        for (idx = 0; idx < link_titles.length; idx++) {
            let tmp = link_titles[idx].innerHTML;
            if (tmp.length > 27) {
                var newLinkTitle = tmp.substring(0, 27) + "...";
                link_titles[idx].innerHTML = newLinkTitle;
            }
        }
    }
}

function post_page_code_blocks() {
    /* Dynamically set code block font size based on screen size.*/

    let threshold = 450;
    let clientWidth = Math.max(document.documentElement.clientWidth, window.innerWidth || 0);

    if (clientWidth < threshold) {
        let code_blocks = document.querySelectorAll('code');
        for (idx = 0; idx < code_blocks.length; idx++) {
            code_blocks[idx].style.fontSize = "10px"
        }
    }
}

function main() {
    return (document.baseURI.includes("posts") ? post_page_code_blocks() : index_page_create_ellipsis());
}

main();