function doubleClickCallback(src, evt)
    % Esta função é chamada quando o usuário dá duplo clique na ROI (drawrectangle).
    if strcmp(evt.SelectionType, 'double')
        uiresume;
    end
end
