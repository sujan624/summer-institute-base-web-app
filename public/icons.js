window.onload = () => {
    icons = document.querySelectorAll('li.list-grouo-item');
    for(let i =0; i < icons.length; i++){
    const icon = icons[i];
    icon.addEventListener('click',chooseIcon);
    }

    function choseIcon(event) {
        const icon = event.target;
        const iconName = icon.dataset.name;
        console.log(iconName);

        iconInput = document.getElementById('icon_input');
        iconInput.value = iconName;
    }
}